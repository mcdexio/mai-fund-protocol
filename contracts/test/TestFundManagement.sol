// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../interface/IPerpetual.sol";
import "../trader/FundManagement.sol";


contract TestFundManagement is
    FundManagement
{
    uint256 private _drawdown;
    uint256 private _totalAssetValue;
    int256 private _leverage;

    constructor(address perpetual) public {
        _perpetual = IPerpetual(perpetual);
    }

    function setDrawdown(uint256 drawdown)
        external
    {
        _drawdown = drawdown;
    }

    function setLeverage(int256 leverage)
        external
    {
        _leverage = leverage;
    }

    function setTotalSupply(uint256 totalSupply)
        external
        virtual
        returns (uint256)
    {
        _totalSupply = totalSupply;
    }

    function setTotalAssetValue(uint256 totalAssetValue)
        external
        returns (uint256)
    {
        _totalAssetValue = totalAssetValue;
    }

    function getTotalAssetValue()
        internal
        virtual
        override
        returns (uint256)
    {
        return _totalAssetValue;
    }

    function getDrawdown()
        internal
        virtual
        override
        returns (uint256)
    {
        return _drawdown;
    }

    function getLeverage()
        internal
        virtual
        override
        returns (int256)
    {
        return _leverage;
    }

    function balance(address account) external view returns (uint256) {
        return _balances[account];
    }

    function getRedeemingLockPeriod() external view returns (uint256) {
        return _redeemingLockPeriod;
    }

    function getDrawdownHighWaterMark() external view returns (uint256) {
        return _drawdownHighWaterMark;
    }

    function getLeverageHighWaterMark() external view returns (uint256) {
        return _leverageHighWaterMark;
    }

    function getEntranceFeeRate() external view returns (uint256) {
        return _entranceFeeRate;
    }

    function getStreamingFeeRate() external view returns (uint256) {
        return _streamingFeeRate;
    }

    function getPerformanceFeeRate() external view returns (uint256) {
        return _performanceFeeRate;
    }
}