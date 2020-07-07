// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../../lib/LibUtils.sol";
import "../../storage/FundStorage.sol";
import "../FundBase.sol";

contract SocialTraderFund is FundStorage, FundBase {
    /**
        for fund manager:
            - claim incentive fee   (manager)
                - performance fee
                - streaming fee
            - pause fund            (manager, administrator)
     */

    event WithdrawIncentiveFee(address indexed maintainer, uint256 totalFee);

    modifier onlyMaintainer() {
        require(msg.sender == _maintainer, "call must be maintainer");
        _;
    }

    /**
     * @dev Calculate incentive fee (streaming fee + performance fee)
     * @return Collateral amount of total fee to claim.
     */
    function getIncentiveFees() external returns (uint256) {
        (, uint256 fee) = calculateFee();
        return fee;
    }

    function withdrawIncentiveFee() external onlyMaintainer {
        claimIncentiveFee();
        require(_totalFeeClaimed > 0, "no withdrawable fee");
        pushCollateral(msg.sender, _totalFeeClaimed);
        emit WithdrawIncentiveFee(_maintainer, _totalFeeClaimed);
        _totalFeeClaimed = 0;
    }

    /**
     * @dev Claim incentive fee (streaming fee + performance fee).
     */
    function claimIncentiveFee() public onlyMaintainer {
        // ensure claiming period >= feeClaimingPeriod (configuration)
        // require(_core.isCooldown(core), "claiming not cooldown");
        // check time is valid.
        require(
            _lastActiveClaimingTime < LibUtils.currentTime(),
            "future claiming time"
        );
        require(
            _lastActiveClaimingTime.add(_feeClaimingPeriod) < LibUtils.currentTime(),
            "claiming too frequent"
        );
        (
            uint256 totalAssetValue,
            uint256 fee
        ) = calculateFee();
        uint256 netAssetValue = totalAssetValue.wdiv(_totalSupply);
        updateFeeState(fee, netAssetValue);
    }
}