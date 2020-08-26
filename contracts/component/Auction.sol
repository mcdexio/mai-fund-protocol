// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "./Status.sol";

/**
 * @title Auction handles share auctions (for redeeming/settling)
 */
contract Auction is Status {
    /**
     * @notice  Get bidding price according to current markprice and slippage.
     * @param   side        Side of position.
     * @param   slippage    Slippage of price, fixed float in decimals 18.
     * @return  priceLimit  Price with slippage.
     * @return  priceLoss   Total loss caused by slippage.
     */
    function _biddingPrice(LibTypes.Side side, uint256 slippage)
        internal
        returns (uint256 priceLimit, uint256 priceLoss)
    {
        uint256 markPrice = _markPrice();
        priceLoss = markPrice.wmul(slippage);
        priceLimit = side == LibTypes.Side.LONG? markPrice.sub(priceLoss): markPrice.add(priceLoss);
    }

    /**
     * @notice Validate bidding price for given side and pricelimit.
     * @param   side        Bidding side.
     * @param   price       Bidding price.
     * @param   priceLimit  Limit of bidding price.1
     */
    function _validatePrice(LibTypes.Side side, uint256 price, uint256 priceLimit)
        internal
        pure
    {
        require(
            (side == LibTypes.Side.LONG && price <= priceLimit) || (side == LibTypes.Side.SHORT && price >= priceLimit),
            "price not match"
        );
    }

    /**
     * @notice bid share from redeeming or shutdown account.
     * @param   shareAmount Amount of share to bid.
     * @param   priceLimit  Price limit.
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
        ( uint256 tradingPrice, uint256 priceLoss ) = _biddingPrice(side, slippage);
        _validatePrice(side, tradingPrice, priceLimit);
        _tradePosition(_msgSender(), _self(), side, tradingPrice, tradingAmount);
        slippageValue = priceLoss.wmul(tradingAmount);
    }

    uint256[20] private __gap;
}