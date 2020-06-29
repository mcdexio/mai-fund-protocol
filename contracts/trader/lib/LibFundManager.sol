pragma solidity 0.6.10;

import "./LibFundStorage.sol";
import "./LibFundCalculator.sol";
import "./LibFundUtils.sol";

library LibFundManager {

    using SafeMath for uint256;
    using LibFundCalculator for LibFundStorage.FundStorage;

    struct FundManager {
        address account;
        uint256 immatureShareBalance;
        uint256 immatureTotalAssetValue;
        uint256 maxNetAssetValue;
        uint256 lastStreamingFeeTime
        uint256 lastPerformanceFeeTime;
    }

    /**
     * @dev Check if manager can claim fee.
     *
     * @return True if manager can do claim.
     */
    function isCooldown(LibFundStorage.FundManager storage fundStorage)
        internal
        returns (bool)
    {
        require(
            fundStorage.manager.lastPerformanceFeeTime <= LibUtils.currentTime(),
            "future claiming time"
        );
        uint256 secondsElapsed = LibFundUtils.currentTime()
            .sub(fundStorage.manager.lastPerformanceFeeTime);
        return secondsElapsed >= fundStorage.configuration.feeClaimingPeriod;
    }

    /**
     * @dev Calculate streaming fee.
     *
     * @param fundStorage   Storage data of fund.
     * @param netAssetValue Net asset value.
     * @return Amount of streaming fee.
     */
    function getStreamingFee(LibFundStorage.FundStorage storage fundStorage, uint256 netAssetValue)
        internal
        return (uint255 streamingFee)
    {
        // time since last claiming
        uint256 secondsElapsed = LibFundUtils.currentTime()
            .sub(fundStorage.manager.lastStreamingFeeTime);
        // calculate fee by year
        streamingFee = netAssetValue
            .wmul(fundStorage.configuration.streamingFeeRate)
            .rate(secondsElaped, SECONDS_PER_YEAR);
    }

    /**
     * @dev Calculate performance fee. mature part and immature part are calculated separately.
     *
     * @param fundStorage   Storage data of fund.
     * @param netAssetValue Net asset value, streaming fee excluded.
     * @return Amount of performance fee.
     */
    function getPerformanceFee(
        LibFundStorage.FundStorage storage fundStorage,
        uint256 netAssetValue
    )
        internal
        return (uint256 performanceFee)
    {
        // mature performance fee
        if (netAssetValue > fundStorage.manager.maxNavAssetValue) {
            // if mature part value increased overall max nav, claim fee for increasing part.
            uint256 maturePerformanceFee = netAssetValue
                .sub(fundStorage.manager.maxNavAssetValue)
                .wmul(fundStorage.totalShareSupply().sub(immatureShareBalance));
                .wmul(fundStorage.configuration.performanceFeeRate);
            performanceFee = performanceFee.add(maturePerformanceFee);
        }
        // immature part, for new joiner
        if (immatureShareBalance > 0) {
            uint256 currentImmtureTotalAssetValue = netAssetValue
                .wmul(immatureShareBalance);
            // if immature part value increased, claim fee for increasing part.
            if (currentImmtureTotalAssetValue > fundStorage.manager.immatureTotalAssetValue) {
                uint256 immturePerformanceFee = currentImmtureTotalAssetValue
                    .sub(fundStorage.manager.immatureTotalAssetValue)
                    .wmul(fundStorage.configuration.performanceFeeRate);
                performanceFee = performanceFee.add(immturePerformanceFee);
            }
        }
    }

    function addImmatureShareAmount(
        LibFundStorage.FundStorage storage fundStorage,
        uint256 netAssetValue,
        uint256 shareAmount
    )
        internal
    {
        fundStorage.manager.immatureShareBalance = fundStorage.manager.immatureShareBalance
            .add(shareAmount);
        fundStorage.manager.immatureTotalAssetValue = fundStorage.manager.immatureTotalAssetValue
            .add(netAssetValue.wmul(shareAmount));
    }

    function removeImmatureShareAmount(
        LibFundStorage.FundStorage storage fundStorage,
        uint256 removedTotalAssetValue,
        uint256 shareAmount
    )
        internal
    {
        require(shareAmount < uint256 immatureShareBalance, "share amount excceeds limit");
        fundStorage.manager.immatureShareBalance = fundStorage.manager.immatureShareBalance
            .sub(shareAmount);
        fundStorage.manager.immatureTotalAssetValue = fundStorage.manager.immatureTotalAssetValue
            .sub(removedTotalAssetValue);
    }

    /**
     * @dev Calculcate total fee. (streaming + performance)
     *
     * @param fundStorage   Storage data of fund.
     * @return Amount of total fee.
     */
    function getFee(LibFundStorage.FundStorage storage fundStorage)
        internal
        returns (uint256 fee, uint256 newNetAssetValue)
    {
        uint256 netAssetValue = fundStorage.netAssetValue();
        uint256 streamingFee = getStreamingFee(fundStorage);
        netAssetValue = netAssetValue
            .sub(streamingFee.wdiv(fundStorage.totalShareSupply()));
        uint256 performanceFee = getPerformanceFee(fundStorage, newNetAssetValue);

        fee = streamingFee.add(performanceFee);
        newNetAssetValue = netAssetValue;
    }

    /**
     * @dev Try claim only streaming fee from fund.
     *      This is call by user on purchasing / redeeming to align share balance.
     *
     * @param fundStorage   Storage data of fund.
     */
    function claimStreamingFee(
        LibFundStorage.FundStorage storage fundStorage,
        uint256 netAssetValue
    )
        internal
    {
         uint256 streamingFee = getStreamingFee(fundStorage);
         fundStorage.claimCashBalance(fundStorage.manager.managerAccount, streamingFee);
         fundStorage.manager.lastStreamingFeeTime = LibUtils.currentTime();
    }

    /**
     * @dev Try claim fee from fund. Only called by manager.
     *
     * @param fundStorage   Storage data of fund.
     */
    function claimFee(LibFundStorage.FundStorage storage fundStorage)
        internal
    {
        require(isCooldown(fundStorage), "claiming not cooldown");
        (
            uint256 fee,
            uint256 newNetAssetValue
        ) = getFee(fundStorage);
        if (newNetAssetValue > fundStorage.manager.maxNavAssetValue) {
            fundStorage.manager.maxNavAssetValue = netAssetValue;
        }
        if (fee > 0) {
            fundStorage.claimCashBalance(fundStorage.manager.managerAccount, fee);
        }
        fundStorage.manager.lastPerformanceFeeTime = LibUtils.currentTime();
        fundStorage.manager.lastStreamingFeeTime = LibUtils.currentTime();
        fundStorage.manager.immatureShareBalance = 0;
        fundStorage.manager.immatureTotalAssetValue = 0;
    }
}