// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./LibConstant.sol";
import "./LibFundCore.sol";
import "./LibFundProperty.sol";
import "./LibMathEx.sol";
import "./LibUtils.sol";

library LibFundFee {

    using SafeMath for uint256;
    using LibMathEx for uint256;
    using LibFundProperty for LibFundCore.Core;

    struct FeeState {
        uint256 totalFeeClaimed;
        uint256 maxNetAssetValue;
        uint256 lastPassiveClaimingTime;
        uint256 lastActiveClaimingTime;
    }

    /**
     * @dev calculate purchase fee.
     * @param core                  Core data of fund.
     * @param purchasedAssetValue   Total asset value to purchase.
     * @return entranceFee Amount of purchase fee.
     */
    function calculateEntranceFee(LibFundCore.Core storage core, uint256 purchasedAssetValue)
        internal
        view
        returns (uint256 entranceFee)
    {
        if (core.configuration.entranceFeeRate == 0) {
            return 0;
        }
        entranceFee = purchasedAssetValue.wmul(core.configuration.entranceFeeRate);
    }

    function annualizedStreamingFeeRate(LibFundCore.Core storage core)
        internal
        view
        returns (uint256)
    {
        uint256 timeElapsed = LibUtils.currentTime().sub(core.feeState.lastPassiveClaimingTime);
        return core.configuration.streamingFeeRate.wfrac(timeElapsed, LibConstant.SECONDS_PER_YEAR);
    }

    /**
     * @dev Claim streaming fee.
     * @param core              Core data of fund.
     * @param totalAssetValue   Total asset value.
     * @return streamingFee Amount of streaming fee.
     */
    function calculateStreamingFee(LibFundCore.Core storage core, uint256 totalAssetValue)
        internal
        view
        returns (uint256 streamingFee)
    {
        if (core.configuration.streamingFeeRate == 0) {
            return 0;
        }
        // time since last claiming
        streamingFee = totalAssetValue.wmul(annualizedStreamingFeeRate(core));
    }

    /**
     * @dev Calculate performance fee. mature part and immature part are calculated separately.
     * @param core              Core data of fund.
     * @param totalAssetValue   Amount of total asset value, streaming fee excluded.
     * @return performanceFee   Amount of performance fee.
     */
    function calculatePerformanceFee(LibFundCore.Core storage core, uint256 totalAssetValue)
        internal
        view
        returns (uint256 performanceFee)
    {
        if (core.configuration.performanceFeeRate == 0) {
            return 0;
        }
        uint256 maxTotalAssetValue = core.feeState.maxNetAssetValue.wmul(core.shareTotalSupply);
        if (totalAssetValue <= maxTotalAssetValue) {
            return 0;
        }
        performanceFee = totalAssetValue.sub(maxTotalAssetValue).wmul(core.configuration.performanceFeeRate);
    }

    /**
     * @dev Calculate streaming fee.
     * @param core          Core data of fund.
     */
    function updateFeeState(LibFundCore.Core storage core, uint256 fee, uint256 netAssetValue)
        internal
    {
        if (netAssetValue > core.feeState.maxNetAssetValue) {
            core.feeState.maxNetAssetValue = netAssetValue;
        }
        core.feeState.totalFeeClaimed = core.feeState.totalFeeClaimed.add(fee);
        if (msg.sender == core.maintainer) {
            core.feeState.lastActiveClaimingTime = LibUtils.currentTime();
        } else {
            core.feeState.lastPassiveClaimingTime = LibUtils.currentTime();
        }
    }
}