// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../lib/LibUtils.sol";
import "../storage/FundStorage.sol";

contract FundConfiguration is FundStorage {

    /**
     * @notice  Set redeeming lock period.
     * @param   period  Lock period in seconds.
     */
    function setRedeemingLockPeriod(uint256 period) internal {
        _redeemingLockPeriod = period;
    }

    /**
     * @notice  Set drawdonw high water mark. Exceeding hwm will cause emergency shutdown.
     * @param   hwm     High water mark for drawdown.
     */
    function setDrawdownHighWaterMark(uint256 hwm) internal {
        require(hwm <= LibConstant.MAX_DRAWDOWN, "hwm exceeds drawdown limit");
        _drawdownHighWaterMark = hwm;
    }

    /**
     * @notice  Set leverage high water mark. Exceeding hwm will cause emergency shutdown.
     * @param   hwm     High water mark for drawdown.
     */
    function setLeverageHighWaterMark(uint256 hwm) internal {
        require(hwm <= LibConstant.MAX_LEVERAGE, "hwm exceeds leverage limit");
        _leverageHighWaterMark = hwm;
    }

    /**
     * @notice  Set entrance fee rete.
     * @param   newRate Rate of entrance fee. 0 < rate <= 100%
     */
    function setEntranceFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "streaming fee rate must be less than 100%");
        _entranceFeeRate = newRate;
    }

    /**
     * @notice  Set streaming fee rete.
     * @param   newRate Rate of streaming fee. 0 < rate <= 100%
     */
    function setStreamingFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "streaming fee rate must be less than 100%");
        _streamingFeeRate = newRate;
    }

    /**
     * @notice  Set performance fee rete.
     * @param   newRate Rate of performance fee. 0 < rate <= 100%
     */
    function setPerformanceFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "performance fee rate must be less than 100%");
        _performanceFeeRate = newRate;
    }
}