// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
// pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

import "../lib/LibConstant.sol";
import "./Status.sol";
import "./Stoppable.sol";

contract Settlement is Status, StoppableUpgradeSafe {

    uint256 internal _drawdownHighWaterMark;
    uint256 internal _leverageHighWaterMark;

    event Shutdown();

    /**
     * @dev     Set drawdonw high water mark. Exceeding hwm will cause emergency shutdown.
     * @param   hwm High water mark for drawdown.
     */
    function _setDrawdownHighWaterMark(uint256 hwm)
        internal
    {
        require(hwm <= LibConstant.MAX_DRAWDOWN, "too high hwm");
        _drawdownHighWaterMark = hwm;
    }

    /**
     * @dev     Set leverage high water mark. Exceeding hwm will cause emergency shutdown.
     * @param   hwm High water mark for drawdown.
     */
    function _setLeverageHighWaterMark(uint256 hwm)
        internal
    {
        require(hwm <= LibConstant.MAX_LEVERAGE, "too high hwm");
        _leverageHighWaterMark = hwm;
    }

    /**
     * @dev     Test can shutdown or not.
     *          1. This is NOT view because method in perpetual.
     *          2. shutdown conditions:
     *              - leveraga reaches limit;
     *              - max drawdown reaches limit.
     * @return True if any condition is met.
     */
    function _canShutdown()
        internal
        virtual
        returns (bool)
    {
        if (_emergency()) {
            return true;
        }
        uint256 netAssetValue = _netAssetValue();
        netAssetValue = _updateFeeState(netAssetValue);
        if (_drawdown(netAssetValue) >= _drawdownHighWaterMark) {
            return true;
        }
        if (_leverage(netAssetValue).abs().toUint256() >= _leverageHighWaterMark) {
            return true;
        }
        return false;
    }

    uint256[18] private __gap;
}