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
    function incentiveFee() external returns (uint256 incentiveFee) {
        (, incentiveFee) = _netAssetValuePerShareAndFee();
        incentiveFee = incentiveFee.add(_totalFeeClaimed);
    }

    function withdrawIncentiveFee() external nonReentrant {
        claimIncentiveFee();
        require(_totalFeeClaimed > 0, "no withdrawable fee");
        _pullCollateralFromPerpetual(_totalFeeClaimed);
        _pushCollateralToUser(payable(_manager), _totalFeeClaimed);
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
        (uint256 netAssetValuePerShare, uint256 fee) = _netAssetValuePerShareAndFee();
        _updateFeeState(fee, netAssetValuePerShare);
    }
}