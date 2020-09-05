// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "./Core.sol";

/**
 * @title   An auction module for selling shares.
 * @dev     Handles share auctions in redeeming / settling.
 */
contract Auction is Core {

    /**
     * @dev     Get bidding price according to current markprice and slippage.
     * @param   side            Side of position.
     * @param   priceLimit      Price limit.
     * @param   slippage        Slippage of price, fixed float in decimals 18.
     * @return  tradingPrice    Trading price plus / minus slippage.
     * @return  priceLoss       Total loss caused by slippage.
     */
    function _biddingPrice(LibTypes.Side side, uint256 priceLimit, uint256 slippage)
        internal
        returns (uint256 tradingPrice, uint256 priceLoss)
    {
        uint256 markPrice = _markPrice();
        priceLoss = markPrice.wmul(slippage);
        if (side == LibTypes.Side.LONG) {
            tradingPrice = markPrice.sub(priceLoss);
            require(tradingPrice <= priceLimit, "price too high");
        } else {
            tradingPrice = markPrice.add(priceLoss);
            require(tradingPrice >= priceLimit, "price too low");
        }
    }

    /**
     * @dev     Bid share from redeeming or shutdown account. Bidders will have a discount on dealing price,
     *          which makes profits to bidder.
     * @param   shareAmount Amount of share to bid.
     * @param   priceLimit  Price limit.
     * @param   side        Side of position to bid.
     * @param   slippage    Slippage for auction shares.
     */
    function _bidShare(
        uint256 shareAmount,
        uint256 priceLimit,
        LibTypes.Side side,
        uint256 slippage
    )
        internal
        returns (uint256 slippageValue)
    {
        LibTypes.MarginAccount memory marginAccount = _marginAccount();
        require(marginAccount.size > 0, "position size is 0");
        require(marginAccount.side == side, "unexpected side");
        uint256 tradingAmount = marginAccount.size.wfrac(shareAmount, totalSupply());
        ( uint256 tradingPrice, uint256 priceLoss ) = _biddingPrice(side, priceLimit, slippage);
        _tradePosition(_msgSender(), _self(), side, tradingPrice, tradingAmount);
        slippageValue = priceLoss.wmul(tradingAmount);
    }

    uint256[20] private __gap;
}