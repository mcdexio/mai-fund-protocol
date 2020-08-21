// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../trader/FundAuction.sol";

contract TestFundAuction is FundAuction {

    address private _mockSelf;

    constructor(address perpetual) public {
        _perpetual = IPerpetual(perpetual);
    }

    function setSelf(address self)
        external
    {
        _mockSelf = self;
    }

    function _self()
        internal
        view
        virtual
        override
        returns (address)
    {
        return _mockSelf;
    }

    function setTotalSupply(uint256 totalSupply)
        external
    {
        _totalSupply = totalSupply;
    }

    function setRedeemingBalances(address account, uint256 amount)
        external
    {
        _redeemingBalances[account] = amount;
    }

    function setRedeemingSlippage(address account, uint256 slippage)
        external
    {
        _redeemingSlippages[account] = slippage;
    }

    function bidShare(
        uint256 shareAmount,
        uint256 priceLimit,
        LibTypes.Side side,
        uint256 slippage
    )
        external
        returns (uint256 slippageValue)
    {
        return _bidShare(shareAmount, priceLimit, side, slippage);
    }


    function biddingPrice(LibTypes.Side side, uint256 slippage)
        external
        returns (uint256 tradingPrice, uint256 priceLoss)
    {
        return _biddingPrice(side, slippage);
    }

    function validateBiddingPrice(LibTypes.Side side, uint256 price, uint256 priceLimit)
        external
        pure
    {
        return _validateBiddingPrice(side, price, priceLimit);
    }
}