// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../lib/LibConstant.sol";
import "./PerpetualWrapper.sol";

contract Configuration is Initializable, PerpetualWrapper {

    uint256 private _drawdownHighWaterMark;
    uint256 private _leverageHighWaterMark;
    uint256 private _redeemingLockPeriod;


    event UpdateConfiguration(bytes32 key, int256 value);

    // /**
    //  * @dev Set value of configuration entry.
    //  * @param key   Name string of entry to set.
    //  * @param value Value of entry to set.
    //  */
    // function updateConfiguration(bytes32 key, int256 value)
    //     external
    //     onlyOwner
    // {
    //     if (key == "redeemingLockPeriod") {
    //         _setRedeemingLockPeriod(uint256(value));
    //     } else if (key == "drawdownHighWaterMark") {
    //         _setDrawdownHighWaterMark(uint256(value));
    //     } else if (key == "leverageHighWaterMark") {
    //         _setLeverageHighWaterMark(uint256(value));
    //     } else if (key == "entranceFeeRate") {
    //         _setEntranceFeeRate(uint256(value));
    //     } else if (key == "streamingFeeRate") {
    //         _setStreamingFeeRate(uint256(value));
    //     } else if (key == "performanceFeeRate") {
    //         _setPerformanceFeeRate(uint256(value));
    //     } else {
    //         revert("unrecognized key");
    //     }
    //     emit UpdateConfiguration(key, value);
    // }

    function redeemingLockPeriod() external view returns (uint256) {
        return _redeemingLockPeriod;
    }

    function drawdownHighWaterMark() external view returns (uint256) {
        return _drawdownHighWaterMark;
    }

    function leverageHighWaterMark() external view returns (uint256) {
        return _leverageHighWaterMark;
    }

    /**
     * @notice  Set redeeming lock period.
     * @param   period  Lock period in seconds.
     */
    function _setRedeemingLockPeriod(uint256 period) internal {
        _redeemingLockPeriod = period;
    }

    /**
     * @notice  Set drawdonw high water mark. Exceeding hwm will cause emergency shutdown.
     * @param   hwm     High water mark for drawdown.
     */
    function _setDrawdownHighWaterMark(uint256 hwm) internal {
        require(hwm <= LibConstant.MAX_DRAWDOWN, "hwm exceeds drawdown limit");
        _drawdownHighWaterMark = hwm;
    }

    /**
     * @notice  Set leverage high water mark. Exceeding hwm will cause emergency shutdown.
     * @param   hwm     High water mark for drawdown.
     */
    function _setLeverageHighWaterMark(uint256 hwm) internal {
        require(hwm <= LibConstant.MAX_LEVERAGE, "hwm exceeds leverage limit");
        _leverageHighWaterMark = hwm;
    }


}