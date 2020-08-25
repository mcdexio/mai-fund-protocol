// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../component/Auction.sol";

contract TestAuction is Auction {

    address private _mockSelf;

    constructor(address perpetual, uint256 cap) public {
        __ERC20Capped_init_unchained(cap);
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

    function validatePrice(LibTypes.Side side, uint256 price, uint256 priceLimit)
        external
        pure
    {
        return _validatePrice(side, price, priceLimit);
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
}