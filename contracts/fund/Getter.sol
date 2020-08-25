// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "./Core.sol";

contract Getter is Core {

    // redeem
    function redeemableShareBalance(address account) external view returns (uint256) {
        return _redeemableShareBalance(account);
    }

    function redeemingLockPeriod() external view returns (uint256) {
        return _redeemingLockPeriod;
    }

    function redeemingBalance(address account) external view returns (uint256) {
        return _redeemingBalances[account];
    }

    function redeemingSlippage(address account) external view returns (uint256) {
        return _redeemingSlippages[account];
    }

    function lastPurchaseTime(address account) external view returns (uint256) {
        return _lastPurchaseTimes[account];
    }

    function maxNetAssetValuePerShare() external view returns (uint256) {
        return _maxNetAssetValuePerShare;
    }

    // collateral
    function collateral() external view returns (address) {
        return address(_collateralToken);
    }

    function scaler() external view returns (uint256) {
        return _scaler;
    }

    function totalFeeClaimed() external view returns (uint256) {
        return _totalFeeClaimed;
    }

    function lastFeeTime() external view returns (uint256) {
        return _lastFeeTime;
    }

    function feeRates() external view returns (uint256, uint256, uint256) {
        return (_entranceFeeRate, _streamingFeeRate, _performanceFeeRate);
    }

    // risk indicator
    function drawdownHighWaterMark() external view returns (uint256) {
        return _drawdownHighWaterMark;
    }

    function leverageHighWaterMark() external view returns (uint256) {
        return _leverageHighWaterMark;
    }

    function leverage() external returns (int256) {
        uint256 netAssetValue = _netAssetValue();
        _updateFeeState(netAssetValue);
        return _leverage(netAssetValue);
    }

    function drawdown() external returns (uint256) {
        uint256 netAssetValue = _netAssetValue();
        _updateFeeState(netAssetValue);
        return _drawdown(netAssetValue);
    }

    // withdraw
    function withdrawableCollateral(address account) external view returns (uint256) {
        return _withdrawableCollaterals[account];
    }
}