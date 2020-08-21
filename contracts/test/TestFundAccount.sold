// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../component/FundAccount.sol";
import "./TestFundConfiguration.sol";

contract TestFundAccount is
    FundAccount,
    TestFundConfiguration
{

    function balance(address trader)
        public
        view
        returns (uint256)
    {
        return _balances[trader];
    }

    function totalSupply()
        public
        view
        returns (uint256)
    {
        return _totalSupply;
    }


    function redeemableShareBalancePublic(address trader)
        public
        view
        returns (uint256)
    {
        return _redeemableShareBalance(trader);
    }

    function increaseShareBalancePublic(address trader, uint256 shareAmount)
        public
    {
        _increaseShareBalance(trader, shareAmount);
    }

    function decreaseShareBalancePublic(address trader, uint256 shareAmount)
        public
    {
        _decreaseShareBalance(trader, shareAmount);
    }

    function mintShareBalancePublic(address trader, uint256 shareAmount)
        public
    {
        _mintShareBalance(trader, shareAmount);
    }

    function burnShareBalancePublic(address trader, uint256 shareAmount)
        public
    {
        _burnShareBalance(trader, shareAmount);
    }

    function canRedeemPublic(address trader)
        public
        view
        returns (bool)
    {
        return _canRedeem(trader);
    }

    function increaseRedeemingShareBalancePublic(address trader, uint256 shareAmount)
        public
    {
        _increaseRedeemingShareBalance(trader, shareAmount);
    }

    function decreaseRedeemingShareBalancePublic(address trader, uint256 shareAmount)
        public
    {
        _decreaseRedeemingShareBalance(trader, shareAmount);
    }

    function setRedeemingSlippagePublic(address trader, uint256 slippage)
        public
    {
        _setRedeemingSlippage(trader, slippage);
    }

    function currentTime()
        public
        view
        returns (uint256)
    {
        return _now();
    }

    function doNothing()
        public
    {
    }
}
