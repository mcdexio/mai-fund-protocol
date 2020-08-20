// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

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
     * @return totalFee IncentiveFee gain since last claiming.
     */
    function incentiveFee()
        external
        returns (uint256 totalFee)
    {
        (, totalFee) = _netAssetValueAndFee();
        totalFee = totalFee.add(_totalFeeClaimed);
    }

    /**
     * @dev     In extreme case, there will not be enough collateral (may be liquidated) to withdraw.
     * @param   collateralAmount    Amount of collateral to withdraw.
     */
    function withdrawIncentiveFee(uint256 collateralAmount)
        external
        nonReentrant
        whenNotPaused
    {
        _claimIncentiveFee();
        require(_totalFeeClaimed > 0, "no withdrawable fee");
        require(collateralAmount <= _totalFeeClaimed, "insufficient fee to withdraw");
        _totalFeeClaimed = _totalFeeClaimed.sub(collateralAmount);
        _pullCollateralFromPerpetual(collateralAmount);
        _pushCollateralToUser(payable(_manager), collateralAmount);
        emit WithdrawIncentiveFee(_manager, collateralAmount);
    }

    /**
     * @dev Claim incentive fee (streaming fee + performance fee).
     */
    function claimIncentiveFee()
        public
        whenNotPaused
    {
        _claimIncentiveFee();
    }

    /**
     * @dev Claim incentive fee (streaming fee + performance fee).
     */
    function _claimIncentiveFee()
        internal
    {
        if (_now() == _lastFeeTime || _totalSupply == 0) {
            return;
        }
        (uint256 netAssetValue, uint256 fee) = _netAssetValueAndFee();
        _updateFeeState(fee, netAssetValue.wdiv(_totalSupply));
    }
}