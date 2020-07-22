// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../../lib/LibUtils.sol";
import "../../storage/FundStorage.sol";
import "../FundBase.sol";
import "../FundManagement.sol";

contract SocialTraderFund is
    FundStorage,
    FundBase,
    FundManagement
{
    event WithdrawIncentiveFee(address indexed maintainer, uint256 totalFee);

    /**
     * @dev Calculate incentive fee (streaming fee + performance fee)
     * @return incentiveFee IncentiveFee gain since last claiming.
     */
    function getIncentiveFee() external returns (uint256 incentiveFee) {
        (, incentiveFee) = getNetAssetValuePerShareAndFee();
    }

    function withdrawIncentiveFee() external nonReentrant {
        claimIncentiveFee();
        require(_totalFeeClaimed > 0, "no withdrawable fee");
        pullCollateralFromPerpetual(_totalFeeClaimed);
        pushCollateralToUser(payable(_manager), _totalFeeClaimed);
        emit WithdrawIncentiveFee(_manager, _totalFeeClaimed);
        _totalFeeClaimed = 0;
    }

    /**
     * @dev Claim incentive fee (streaming fee + performance fee).
     */
    function claimIncentiveFee() public {
        if (now == _lastFeeTime) {
            return;
        }
        (uint256 netAssetValuePerShare, uint256 fee) = getNetAssetValuePerShareAndFee();
        updateFeeState(fee, netAssetValuePerShare);
    }
}