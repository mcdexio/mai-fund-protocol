// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
// pragma experimental ABIEncoderV2;

import "../component/Settlement.sol";

contract TestSettlement is Settlement {

    bool private _mockEmergency;
    uint256 private _mockDrawdown;
    int256 private _mockLeverage;

    constructor() public {
        __ERC20CappedRedeemable_init_unchained(1000);
        _mint(_msgSender(), 1);
    }


    function drawdownHighWaterMark()
        external
        view
        returns (uint256)
    {
        return _drawdownHighWaterMark;
    }

    function leverageHighWaterMark()
        external
        view
        returns (uint256)
    {
        return _leverageHighWaterMark;
    }

    function setDrawdownHighWaterMark(uint256 hwm)
        external
    {
        _setDrawdownHighWaterMark(hwm);
    }

    function setLeverageHighWaterMark(uint256 hwm)
        external
    {
        _setLeverageHighWaterMark(hwm);
    }

    function setEmergency(bool emergency)
        external
    {
        _mockEmergency = emergency;
    }

    function _emergency()
        internal
        view
        override
        returns (bool)
    {
        return _mockEmergency;
    }

    function setDrawdown(uint256 drawdown)
        external
    {
        _mockDrawdown = drawdown;
    }

    function _drawdown(uint256)
        internal
        view
        override
        returns (uint256)
    {
        return _mockDrawdown;
    }

    function setLeverage(int256 leverage)
        external
    {
        _mockLeverage = leverage;
    }

    function _leverage(uint256)
        internal
        override
        returns (int256)
    {
        return _mockLeverage;
    }

    function canShutdown()
        external
        returns (bool)
    {
        return _canShutdown();
    }

    function _netAssetValue()
        internal
        virtual
        override
        returns (uint256)
    {
        return 0;
    }
}