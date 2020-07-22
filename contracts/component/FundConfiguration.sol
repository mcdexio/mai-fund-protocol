// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../lib/LibUtils.sol";
import "../storage/FundStorage.sol";

contract FundConfiguration is FundStorage {

    function setRedeemingLockPeriod(uint256 period) internal {
        _redeemingLockPeriod = period;
    }

    function setDrawdownHighWaterMark(uint256 hwm) internal {
        require(hwm <= LibConstant.MAX_DRAWDOWN, "hwm exceeds drawdown limit");
        _drawdownHighWaterMark = hwm;
    }

    function setLeverageHighWaterMark(uint256 hwm) internal {
        require(hwm <= LibConstant.MAX_LEVERAGE, "hwm exceeds leverage limit");
        _leverageHighWaterMark = hwm;
    }

    function setEntranceFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "streaming fee rate must be less than 100%");
        _entranceFeeRate = newRate;
    }

    function setStreamingFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "streaming fee rate must be less than 100%");
        _streamingFeeRate = newRate;
    }

    function setPerformanceFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "performance fee rate must be less than 100%");
        _performanceFeeRate = newRate;
    }
}