pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./LibFundCore.sol";
import "./LibFundCalculator.sol";
import "./LibFundUtils.sol";

library LibFundFees {

    using SafeMath for uint256;
    using LibFundCalculator for LibFundStorage.FundStorage;

    struct FeeState {
        uint256 totalFeeClaimed;
        uint256 maxNetAssetValue;
        uint256 lastFeeTime
        uint256 lastPerformanceFeeTime;
    }

    /**
     * @dev calculate purchase fee.
     *
     * @param state                 Fee state.
     * @param purchasedAssetValue   Total asset value to purchase.
     * @return Amount of purchase fee.
     */
    function calculateEntranceFee(LibFundCore.Core storage core, uint256 purchasedAssetValue)
        internal
        returns (uint256 entranceFee)
    {
        if (core.configuration.entranceFeeRate == 0) {
            return;
        }
        entranceFee = purchasedAssetValue.wmul(core.configuration.entranceFeeRate);
    }

    function annualizedStreamingFeeRate(LibFundCore.Core storage core)
        internal
        view
        returns (uint256)
    {
        uint256 timeElapsed = LibFundUtils.currentTime().sub(core.state.lastFeeTime);
        return core.configuration.streamingFeeRate.wfrac(timeElapsed, SECONDS_PER_YEAR);
    }

    /**
     * @dev Claim streaming fee.
     *
     * @param state         Fee state.
     * @param assetValue    Total asset value to purchase.
     * @return Amount of streaming fee.
     */
    function calculateStreamingFee(LibFundCore.Core storage core, uint256 totalAssetValue)
        internal
        return (uint255 streamingFee)
    {
        if (state.streamingFeeRate == 0) {
            return 0;
        }
        // time since last claiming
        streamingFee = totalAssetValue.wmul(annualizedStreamingFeeRate(core));
    }

    /**
     * @dev Calculate performance fee. mature part and immature part are calculated separately.
     *
     * @param fundStorage   Storage data of fund.
     * @param netAssetValue Net asset value, streaming fee excluded.
     * @return Amount of performance fee.
     */
    function calculatePerformanceFee(LibFundCore.Core storage core, uint256 totalAssetValue, uint256 streamingFee)
        internal
        return (uint256 performanceFee)
    {
        uint256 maxTotalAssetValue = fundStorage.manager.maxNavAssetValue.wmul(core.shareTotalAmount);
        if (totalAssetValue <= maxTotalAssetValue) {
            return 0;
        }
        performanceFee = totalAssetValue.sub(maxTotalAssetValue).wmul(core.configuration.performanceFeeRate);
    }

    /**
     * @dev Try claim only streaming fee from fund.
     *      This is call by user on purchasing / redeeming to align share balance.
     *
     * @param fundStorage   Storage data of fund.
     */
    function claimFee(LibFundCore.Core storage core, uint256 totalAssetValue) internal {
        uint256 streamingFee = calculateStreamingFee(core);
        uint256 performanceFee = calculatePerformanceFee(core, totalAssetValue, streamingFee);
        uint256 fee = streamingFee.add(performanceFee);

        updateFeeState(core, fee);
    }

    /**
     * @dev Calculate streaming fee.
     *
     * @param state         Fee state.
     * @param assetValue    Total asset value to purchase.
     * @return Amount of streaming fee.
     */
    function updateFeeState(LibFundCore.Core storage core)
        internal
        return (uint256 streamingFee)
    {
        state.totalFeeClaimed = state.totalFeeClaimed.add(fee);
        fundStorage.manager.lastFeeTime = LibUtils.currentTime();
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
}