// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../component/Auction.sol";

contract TestAuction is Auction {

    address private _mockSelf;

    constructor(address perpetual, uint256 cap) public {
        __ERC20CappedRedeemable_init_unchained(cap);
        __MarginAccount_init_unchained(perpetual);
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

    function increaseTotalSupply(uint256 totalSupply)
        external
    {
        _mint(_mockSelf, totalSupply);
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

    function biddingPrice(LibTypes.Side side, uint256 priceLimit, uint256 slippage)
        external
        returns (uint256 tradingPrice, uint256 priceLoss)
    {
        return _biddingPrice(side, priceLimit, slippage);
    }
}