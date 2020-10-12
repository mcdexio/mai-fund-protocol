// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "./SettleableFund.sol";

contract Getter is SettleableFund {
    // asset value
    /**
     * @dev This is overrided version from Core.sol
     */
    function netAssetValue() public returns (uint256) {
        return _updateNetAssetValue();
    }

    function netAssetValuePerShare() public returns (uint256) {
        return _netAssetValuePerShare(_updateNetAssetValue());
    }

    function state() public view returns (FundState) {
        return _state;
    }

    function cap() public view returns (uint256) {
        return _cap;
    }

    // redeem
    function redeemableShareBalance(address account) public view returns (uint256) {
        return _redeemableShareBalance(account);
    }

    function redeemingLockPeriod() public view returns (uint256) {
        return _redeemingLockPeriod;
    }

    function redeemingBalance(address account) public view returns (uint256) {
        return _redeemingBalances[account];
    }

    function redeemingSlippage(address account) public view returns (uint256) {
        return _redeemingSlippages[account];
    }

    function lastPurchaseTime(address account) public view returns (uint256) {
        return _lastPurchaseTimes[account];
    }

    function historicMaxNetAssetValuePerShare() public view returns (uint256) {
        return _historicMaxNetAssetValuePerShare;
    }

    // collateral
    function collateral() public view returns (address) {
        return address(_collateralToken);
    }

    function scaler() public view returns (uint256) {
        return _scaler;
    }

    function totalFeeClaimable() public view returns (uint256) {
        return _totalFeeClaimable;
    }

    function lastFeeTime() public view returns (uint256) {
        return _lastFeeTime;
    }

    function feeRates()
        public
        view
        returns (uint256 entranceFeeRate, uint256 streamingFeeRate, uint256 performanceFeeRate )
    {
        entranceFeeRate = _entranceFeeRate;
        streamingFeeRate = _streamingFeeRate;
        performanceFeeRate = _performanceFeeRate;
    }

    // risk indicator
    function drawdownHighWaterMark() public view returns (uint256) {
        return _drawdownHighWaterMark;
    }

    function leverageHighWaterMark() public view returns (uint256) {
        return _leverageHighWaterMark;
    }

    function canShutdown() public returns (bool) {
        return _canShutdown();
    }

    function leverage() public returns (int256) {
        return _leverage(_updateNetAssetValue());
    }

    function drawdown() public returns (uint256) {
        return _drawdown(_updateNetAssetValue());
    }
}