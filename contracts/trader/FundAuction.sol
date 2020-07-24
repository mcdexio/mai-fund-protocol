// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "../lib/LibTypes.sol";
import "../storage/FundStorage.sol";
import "../component/FundProperty.sol";

contract FundAuction is
    FundStorage,
    FundProperty
{
    using SafeMath for uint256;

    /**
     * @notice bid share from redeeming or shutdown account.
     * @param   trader      Address of redeeming account.
     * @param   shareAmount Amount of share to bid.
     * @param   priceLimit  Price limit.
     */
    function bidShare(
        address trader,
        uint256 shareAmount,
        uint256 priceLimit,
        LibTypes.Side side
    )
        internal
        returns (uint256 slippageValue)
    {
        require(shareAmount <= _redeemingBalances[trader], "insufficient shares to take");
        // trading price and loss amount equivalent to slippage
        LibTypes.MarginAccount memory fundMarginAccount = getMarginAccount();
        require(fundMarginAccount.side == side, "unexpected side");
        uint256 redeemPercentage = shareAmount.wdiv(_totalSupply);
        // TODO: align to tradingLotSize
        uint256 redeemAmount = fundMarginAccount.size.wmul(redeemPercentage);
        LibTypes.Side redeemingSide = fundMarginAccount.side == LibTypes.Side.LONG?
            LibTypes.Side.SHORT : LibTypes.Side.LONG;
        uint256 slippage = _redeemingSlippage[trader];
        (
            uint256 tradingPrice,
            uint256 priceLoss
        ) = getBiddingPrice(fundMarginAccount.side, slippage);
        validateBiddingPrice(side, tradingPrice, priceLimit);
        _perpetual.tradePosition(
            self(),
            msg.sender,
            redeemingSide,
            tradingPrice,
            redeemAmount
        );
        slippageValue = priceLoss.wmul(redeemAmount);
    }

    /**
     * @notice  Get bidding price according to current markprice and slippage.
     * @param   side        Side of position.
     * @param   slippage    Slippage of price, fixed float in decimals 18.
     * @return  tradingPrice    Price with slippage.
     * @return  priceLoss       Total loss caused by slippage.
     */
    function getBiddingPrice(LibTypes.Side side, uint256 slippage)
        internal
        returns (uint256 tradingPrice, uint256 priceLoss)
    {
        uint256 markPrice = _perpetual.markPrice();
        priceLoss = markPrice.wmul(slippage);
        tradingPrice = side == LibTypes.Side.LONG? markPrice.add(priceLoss): markPrice.sub(priceLoss);
    }

    function validateBiddingPrice(LibTypes.Side side, uint256 price, uint256 priceLimit) internal pure {
        if (side == LibTypes.Side.LONG) {
            require(price <= priceLimit, "price too low for long");
        } else {
            require(price >= priceLimit, "price too high for short");
        }
    }
}