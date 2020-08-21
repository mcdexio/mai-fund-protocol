// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

import "../lib/LibConstant.sol";
import "./Account.sol";
import "./ERC20Wrapper.sol";
import "./Property.sol";
import "./Stoppable.sol";

contract Settlement is StoppableUpgradeSafe, Account, ERC20Wrapper, Property {

    uint256 private _drawdownHighWaterMark;
    uint256 private _leverageHighWaterMark;
    uint256 private _redeemingLockPeriod;

    event Settle();

    function drawdownHighWaterMark() external view returns (uint256) {
        return _drawdownHighWaterMark;
    }

    function leverageHighWaterMark() external view returns (uint256) {
        return _leverageHighWaterMark;
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

    /**
     * @notice  Test can shutdown or not.
     * @dev     1. This is NOT view because method in perpetual.
     *          2. shutdown conditions:
     *              - leveraga reaches limit;
     *              - max drawdown reaches limit.
     * @return True if any condition is met.
     */
    function canShutdown()
        public
        returns (bool)
    {
        uint256 maxDrawdown = _drawdown();
        if (maxDrawdown >= _drawdownHighWaterMark) {
            return true;
        }
        uint256 leverage = leverage().abs().toUint256();
        if (leverage >= _leverageHighWaterMark) {
            return true;
        }
        return false;
    }

    /**
     * @notice  Call by admin, or by anyone when shutdown conditions are met.
     * @dev     No way back.
     */
    function shutdown()
        external
        whenNotStopped
    {
        require(msg.sender == owner() || canShutdown(), "caller must be administrator or cannot shutdown");

        // claim fee until shutting down
        ( uint256 netAssetValue, _ ) = _netAssetValueAndFee();
        ( uint256 netAssetValuePerShare, uint256 fee ) = _netAssetValuePerShare(netAssetValue);
        _updateFeeState(fee, netAssetValuePerShare);
        _setRedeemingShareBalance(_self()) = totalSupply();
        // enter shutting down mode.
        _stop();
        emit Shutdown();
    }
}