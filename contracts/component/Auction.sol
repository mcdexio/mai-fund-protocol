// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "./Account.sol";
import "./PerpetualWrapper.sol";

contract Auction is Account, PerpetualWrapper {

    /**
     * @notice  Get bidding price according to current markprice and slippage.
     * @param   side        Side of position.
     * @param   slippage    Slippage of price, fixed float in decimals 18.
     * @return  tradingPrice    Price with slippage.
     * @return  priceLoss       Total loss caused by slippage.
     */
    function _biddingPrice(LibTypes.Side side, uint256 slippage)
        internal
        returns (uint256 tradingPrice, uint256 priceLoss)
    {
        uint256 markPrice = _markPrice();
        priceLoss = markPrice.wmul(slippage);
        tradingPrice = side == LibTypes.Side.LONG? markPrice.sub(priceLoss): markPrice.add(priceLoss);
    }

    /**
     * @notice Validate bidding price for given side and pricelimit.
     * @param   side        Bidding side.
     * @param   price       Bidding price.
     * @param   priceLimit  Limit of bidding price.
     */
    function _validatePrice(LibTypes.Side side, uint256 price, uint256 priceLimit)
        internal
        pure
    {
        if (side == LibTypes.Side.LONG) {
            require(price <= priceLimit, "price too low for long");
        } else {
            require(price >= priceLimit, "price too high for short");
        }
    }

    /**
     * @notice bid share from redeeming or shutdown account.
     * @param   shareAmount Amount of share to bid.
     * @param   priceLimit  Price limit.
     */
    function _bidShares(
        uint256 shareAmount,
        uint256 priceLimit,
        LibTypes.Side side,
        uint256 slippage
    )
        internal
        returns (uint256 slippageValue)
    {
        LibTypes.MarginAccount memory marginAccount = _marginAccount();
        require(marginAccount.size > 0, "no position to trade");
        require(marginAccount.side == side, "unexpected trading side");
        uint256 tradingAmount = marginAccount.size.wfrac(shareAmount, totalSupply());
        ( uint256 tradingPrice, uint256 priceLoss ) = _biddingPrice(side, slippage);
        _validatePrice(side, tradingPrice, priceLimit);
        _tradePosition(side, tradingPrice, tradingAmount);
        slippageValue = priceLoss.wmul(tradingAmount);
    }
}