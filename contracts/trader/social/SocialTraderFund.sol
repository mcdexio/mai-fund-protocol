// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../FundBase.sol";

import "../../lib/LibFundFee.sol";
import "../../lib/LibFundProperty.sol";
import "../../lib/LibUtils.sol";

contract SocialTraderFund is FundBase {

    using LibFundProperty for LibFundCore.Core;
    using LibFundFee for LibFundCore.Core;

    /**
        for fund manager:
            - claim incentive fee   (manager)
                - performance fee
                - streaming fee
            - pause fund            (manager, administrator)
     */

    modifier onlyMaintainer() {
        require(msg.sender == _core.maintainer, "call must be maintainer");
        _;
    }

    /**
     * @dev Calculate incentive fee (streaming fee + performance fee)
     * @return Collateral amount of total fee to claim.
     */
    function getIncentiveFees() external returns (uint256) {
        uint256 totalAssetValue = _core.totalAssetValue();
        uint256 streamingFee = _core.calculateStreamingFee(totalAssetValue);
        totalAssetValue = totalAssetValue.sub(streamingFee);
        uint256 performanceFee = _core.calculatePerformanceFee(totalAssetValue);
        return streamingFee.add(performanceFee);
    }

    function withdrawIncentiveFees() external onlyMaintainer {
        require(_core.feeState.totalFeeClaimed > 0, "no withdrawable fee");
        _core.collateral.pushCollateral(msg.sender, _core.feeState.totalFeeClaimed);
        _core.feeState.totalFeeClaimed = 0;
    }

    /**
     * @dev Claim incentive fee (streaming fee + performance fee).
     */
    function claimIncentiveFee() external onlyMaintainer {
        // ensure claiming period >= feeClaimingPeriod (configuration)
        // require(_core.isCooldown(core), "claiming not cooldown");
        // check time is valid.
        require(
            _core.feeState.lastActiveClaimingTime < LibUtils.currentTime(),
            "future claiming time"
        );
        require(
            _core.feeState.lastActiveClaimingTime.add(_core.configuration.feeClaimingPeriod) < LibUtils.currentTime(),
            "claiming too frequent"
        );
        // get fees
        uint256 totalAssetValue = _core.totalAssetValue();
        uint256 streamingFee = _core.calculateStreamingFee(totalAssetValue);
        totalAssetValue = totalAssetValue.sub(streamingFee);
        uint256 performanceFee = _core.calculatePerformanceFee(totalAssetValue);
        totalAssetValue = totalAssetValue.sub(performanceFee);
        uint256 netAssetValue = totalAssetValue.wdiv(_core.shareTotalSupply);
        // update time and hwm
        _core.updateFeeState(streamingFee.add(performanceFee), netAssetValue);
    }
}