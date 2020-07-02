// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../storage/UpgradableProxy.sol";
import "../interface/IGlobalConfig.sol";
import "../trader/social/SocialTraderFund.sol";
import "../trader/robot/AutoTraderFund.sol";

/**
 * @title Administration module for fund.
 */
contract FundAdministration {

    IGlobalConfig private _globalConfig;
    address[] _allFunds;
    mapping(address => bool) public _funds;

    event CreateSocialTradingFund(address indexed newFund);
    event CreateAutoTradingFund(address indexed newFund);
    event ShutdownFund(address indexed fund);

    constructor(address globalConfig) public {
        _globalConfig = IGlobalConfig(globalConfig);
    }

    modifier onlyAdministrator() {
        require(msg.sender == _globalConfig.owner(), "unauthorized caller");
        _;
    }

    /**
     * @dev Get address of global config.
     * @return Address of account owning GlobalConfig contract.
     */
    function globalConfig() public view returns (address) {
        return address(_globalConfig);
    }

    /**
     * @dev Use owner of global config as administrator.
     * @return Address of account owning GlobalConfig contract.
     */
    function administrator() public view returns (address) {
        return _globalConfig.owner();
    }

    /**
     * @dev Create a fund maintained by social trader.
     * @param name                  Name of fund (share token).
     * @param symbol                Symbol of fund (share token).
     * @param maintainer            Address of fund maintainer (social trader).
     * @param perpetual             Address of undelaying perpetual contract.
     * @param collateralDecimals    Decimals of collateral.
     * @param configuration         Array of configurations. See LibFundConfiguration for item arrangement.
     * @return Address of new fund.
     */
    function createSocialTradingFund(
        string calldata name,
        string calldata symbol,
        address maintainer,
        address perpetual,
        uint8 collateralDecimals,
        uint256[] calldata configuration
    )
        external
        onlyAdministrator
        returns (address)
    {
        UpgradableProxy fundProxy = new UpgradableProxy();
        fundProxy.initialize(
            name,
            symbol,
            maintainer,
            perpetual,
            collateralDecimals,
            configuration
        );
        SocialTraderFund trader = new SocialTraderFund();
        fundProxy.upgradeTo("", address(trader));

        address fundProxyAddress = address(fundProxy);
        _funds[fundProxyAddress] = true;
        _allFunds.push(fundProxyAddress);

        emit CreateSocialTradingFund(fundProxyAddress);
        return fundProxyAddress;
    }

    /**
     * @dev Create a fund maintained by strategy contract.
     *      Rebalance can be triggered by anyone once the condition defined by stratege satisfied.
     * @param name                  Name of fund (share token).
     * @param symbol                Symbol of fund (share token).
     * @param strategy              Address of fund maintainer (strategy).
     * @param perpetual             Address of undelaying perpetual contract.
     * @param collateralDecimals    Decimals of collateral.
     * @param configuration         Array of configurations. See LibFundConfiguration for item arrangement.
     * @return Address of new fund.
     */
    function createAutoTradingFund(
        string calldata name,
        string calldata symbol,
        address strategy,
        address perpetual,
        uint8 collateralDecimals,
        uint256[] calldata configuration
    )
        external
        onlyAdministrator
        returns (address)
    {
        UpgradableProxy fundProxy = new UpgradableProxy();
        fundProxy.initialize(
            name,
            symbol,
            strategy,
            perpetual,
            collateralDecimals,
            configuration
        );
        AutoTraderFund trader = new AutoTraderFund(strategy);
        fundProxy.upgradeTo("", address(trader));

        address fundProxyAddress = address(fundProxy);
        _funds[fundProxyAddress] = true;
        _allFunds.push(fundProxyAddress);

        emit CreateSocialTradingFund(fundProxyAddress);
        return fundProxyAddress;
    }

    /**
     * @dev Shutdown a running fund.
     */
    function shutdownFund(address fund) external onlyAdministrator {
        require(_funds[fund], "fund not exist");
        _funds[fund] = false;

        // TODO: call method to turn fund into emergency shutdown state.
        emit ShutdownFund(fund);
    }
}