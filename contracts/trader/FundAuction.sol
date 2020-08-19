// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "../lib/LibMathEx.sol";
import "../lib/LibTypes.sol";
import "../storage/FundStorage.sol";
import "../component/FundProperty.sol";

contract FundAuction is
    FundStorage,
    FundProperty
{
    using SafeMath for uint256;
    // using LibMathEx for uint256;
    using LibTypes for LibTypes.Side;

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
        // trading price and loss amount equivalent to slippage
        LibTypes.MarginAccount memory marginAccount = _marginAccount();
        if (marginAccount.size == 0) {
            return 0;
        }
        require(marginAccount.side == side, "unexpected side");
        // redeeming amount aligned to lotSize.
        uint256 lotSize = _perpetual.getGovernance().lotSize;
        uint256 redeemAmount = marginAccount.size.wfrac(shareAmount, _totalSupply);
        redeemAmount = redeemAmount.sub(redeemAmount.mod(lotSize));
        (
            uint256 tradingPrice,
            uint256 priceLoss
        ) = _biddingPrice(marginAccount.side, slippage);
        _validateBiddingPrice(side, tradingPrice, priceLimit);
        _perpetual.tradePosition(
            msg.sender,
            _self(),
            side,
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
    function _biddingPrice(LibTypes.Side side, uint256 slippage)
        internal
        returns (uint256 tradingPrice, uint256 priceLoss)
    {
        uint256 markPrice = _perpetual.markPrice();
        priceLoss = markPrice.wmul(slippage);
        tradingPrice = side == LibTypes.Side.LONG? markPrice.sub(priceLoss): markPrice.add(priceLoss);
    }

    /**
     * @notice Validate bidding price for given side and pricelimit.
     * @param   side        Bidding side.
     * @param   price       Bidding price.
     * @param   priceLimit  Limit of bidding price.
     */
    function _validateBiddingPrice(LibTypes.Side side, uint256 price, uint256 priceLimit) internal pure {
        if (side == LibTypes.Side.LONG) {
            require(price <= priceLimit, "price too low for long");
        } else {
            require(price >= priceLimit, "price too high for short");
        }
    }
}