// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../component/Collateral.sol";

contract TestCollateral is Collateral {

    function initialize(address collateral, uint8 decimals)
        public
        initializer
    {
        __Collateral_init_unchained(collateral, decimals);
    }

    function collateral()
        external
        view
        returns (address)
    {
        return address(_collateralToken);
    }

    function scalar()
        external
        view
        returns (uint256)
    {
        return _scalar;
    }

    function retrieveDecimals(address token)
        external
        view
        returns (uint8, bool)
    {
        return _retrieveDecimals(token);
    }

    function isCollateralERC20()
        external
        view
        returns (bool)
    {
        return _isCollateralERC20();
    }

    function approvalTo(address spender, uint256 amount)
        external
    {
        _approvalTo(spender, amount);
    }

    function pullFromUser(address trader, uint256 amount)
        external
        payable
        returns (uint256)
    {
        return _pullFromUser(trader, amount);
    }

    function pushToUser(address payable trader, uint256 amount)
        external
        returns (uint256)
    {
        return _pushToUser(trader, amount);
    }

    function toInternalAmount(uint256 rawAmount)
        external
        view
        returns (uint256)
    {
        return _toInternalAmount(rawAmount);
    }

    function toRawAmount(uint256 amount)
        external
        view
        returns (uint256)
    {
        return _toRawAmount(amount);
    }
}