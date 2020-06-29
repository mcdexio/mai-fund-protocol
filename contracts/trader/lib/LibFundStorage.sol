pragma solidity 0.6.10;

import "./LibFundAccount.sol";
import "./LibFundConfiguration.sol";

import "./LibCollateral.sol";
import "./LibUtils.sol";

library LibFundStorage {

    struct FundStorage {
        bool initialized;
        string name;
        string symbol;
        uint256 totalShareSupply;

        LibCollateral.CollateralSpec collateral;
        IPerpetual perpetual;

        LibFundManager manager;
        LibFundConfiguration.FundConfiguration configuration;

        mapping(address => LibFundAccount.FundAccount) accounts;
    }

    /**
     * @dev Initialize data structure. Only can be called once.
     */
    function initialize(
        FundStorage storage fundStorage,
        string memory name,
        string memory symbol,
        address perpetual,
        address manager,
        uint8 collateralDecimals,
        uint256[] initialConfiguration
    )
        internal
    {
        require(!fundStorage.initialized, "cannot reinitialize fund storage");

        fundStorage.name = name;
        fundStorage.symbol = symbol;
        fundStorage.perpetual = IPerpetual(perpetual);
        fundStorage.manager.account = manager;
        fundStorage.collateral.initialize(fundStorage.perpetual.collateral(), collateralDecimals);
        fundStorage.configuration.initalize(fundStorage.configuration, initialConfiguration);

        fundStorage.initialized = true;
    }

    /**
     * @dev Purchase shares. Purchasing happens immediately.
     *      All collatral goes into margin account, makes the leverage of the margin account become lower.
     */
    function purchase(
        FundStorage storage fundStorage,
        address trader,
        uint256 netAssetValue,
        uint256 shareAmount
    )
        internal
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        // - calculcate collateral required for share amount (NAV x amount)
        uint256 collateralRequired = netAssetValue.wmul(shareAmount);
        // - there is an entrance fee for purchased value.
        if (_fundStorage.configuration.entranceFeeRate > 0) {
            uint256 entranceFee = _fundStorage.configuration.entranceFeeRate.wmul(collateralRequired);
            collateralRequired = collateralRequired.add(entranceFee);
        }
        // - convert fee from internal decimals to raw
        uint256 rawCollateralRequired = _fundStorage.collateral.toRaw(collateralRequired);
        // - pull collateral
        _fundStorage.collateral.pullCollateral(trader, rawCollateralRequired);
        // - update manager status
        _fundStorage.manager.claimStreamingFee();
        _fundStorage.manager.addImmatureShareAmount(netAssetValue, shareAmount);
        // - update trader account status
        _fundStorage.accounts[trader].purchase(netAssetValue, shareAmount);
        // - update total supply
        _fundStorage.totalShareSupply = _fundStorage.totalShareSupply.add(shareAmount);
    }

    function hasPastlockPeriod(FundStorage storage fundStorage, address trader) internal view returns (bool) {
        require(fundStorage.accounts[trader].lastEntryTime <= LibUtils.currentTime(), "future entry time");
        return LibUtils.currentTime() > fundStorage.accounts[trader].lastEntryTime.add(lockedPeriod);
    }

    /**
     * @dev Request to reedem shares. Use must wait a period time defined in configuration before redeeming.
     */
    function requestToRedeem(
        FundStorage storage fundStorage,
        address trader,
        uint256 shareAmount
    )
        internal
    {
        require(hasPastlockPeriod(fundStorage, trader), "shares is locked");
        fundStorage.accounts[trader].requestToRedeem(shareAmount);
    }

    /**
     * @dev Redeem shares.
     */
    function redeem(
        FundStorage storage fundStorage,
        address trader,
        uint256 shareAmount
    )
        internal
    {
        // steps:
        //  1. calculate mature/immature part for net value.
        //  2. get fee for mature part.
        //  3. get fee for immature part.
        //  4. pull collateral - fee
        //  5. fee to manager
        require(shareAmount > 0, "share amount must be greater than 0");
        // - calculate decreased amount
        (
            uint256 decreasedImmatureShareBalance,
            uint256 decreasedShareBalance
        ) = fundStorage.accounts[trader].redeem(shareAmount);

        // - calc fee for immature part of balance
        uint256 netAssetValue = fundStorage.getNetAssetValue();
        // streaming fee
        fundStorage.claimStreamingFee();
        //
        uint256 immatureValue = decreasedImmatureShareBalance
            .wmul(fundStorage.accounts[trader].immatureNetAssetValue);
        uint256 redeemingFee;
        if (netAssetValue > immatureValue) {
            uint256 immatureFee = netAssetValue.sub(immatureValue)
                .wmul(fundStorage.configuration.performanceFeeRate);
            redeemingFee = redeemingFee.add(immatureFee);
        }
        // - calc performance fee
        if (netAssetValue > hwm) {
            uint256 performanceFee = netAssetValue.sub(hwm)
                .wmul(fundStorage.configuration.performanceFeeRate);
            redeemingFee = redeemingFee.add(performanceFee);
        }
        uint256 rawRedeemingFee = fundStorage.collateral.toRaw(redeemingFee);
        uint256 collateralToReturn = netAssetValue
            .wmul(decreasedImmatureShareBalance.add(decreasedShareBalance))
            .sub(rawRedeemingFee);
        uint256 rawcollateralToReturn = fundStorage.collateral.toRaw(collateralToReturn);
        // - transfer balance
        fundStorage.collateral.pushCollateral(trader, rawcollateralToReturn);
        fundStorage.collateral.pushCollateral(manager, rawRedeemingFee);
        // - increase total supply
        _fundStorage.totalShareSupply = _fundStorage.totalShareSupply.sub(shareAmount);
    }
}