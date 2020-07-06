// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "../lib/LibConstant.sol";
import "../lib/LibMathEx.sol";

import "../storage/FundStorage.sol";
import "./FundBase.sol";

contract FundOperation is FundBase {
    using SafeMath for uint256;
    using LibMathEx for uint256;

    event Purchase(address indexed trader, uint256 netAssetValue, uint256 shareAmount);
    event RequestToRedeem(address indexed trader, uint256 shareAmount, uint256 slippage);
    event CancelRedeeming(address indexed trader, uint256 shareAmount);
    event Redeem(address indexed trader, uint256 netAssetValue, uint256 shareAmount);

    /**
        for fund user:
            - purchase              (user)
            - redeem                (user)
            - withdraw              (user)
            - take                  (market maker)
            - shutdown              (anyone)
     */

    /**
     * @dev Initialize function for upgradable proxy.
     */
    function initialize()
        external
    {
        // TODO: initialize
    }

    /**
     * @dev Call once, when NAV is 0 (position size == 0).
     * @param shareAmount           Amount of shares to purchase.
     * @param initialNetAssetValue  Initial NAV defined by creator.
     */
    function create(uint256 shareAmount, uint256 initialNetAssetValue)
        external
        payable
    {
        require(shareAmount > 0, "share amount cannot be 0");
        // TODO: create condition
        require(_totalSupply == 0, "share supply is not 0");
        _purchase(msg.sender, shareAmount, initialNetAssetValue);
    }

    /**
     * @dev Purchase share, Total collataral required = amount x unit net value.
     * @param shareAmount           Amount of shares to purchase.
     * @param netAssetValueLimit    NAV price limit to protect trader's dealing price.
     */
    function purchase(uint256 shareAmount, uint256 netAssetValueLimit)
        external
        payable
    {
        (
            uint256 totalAssetValue,
            uint256 fee
        ) = calculateFee();

        uint256 netAssetValue = totalAssetValue.wdiv(_totalSupply);
        require(netAssetValue <= netAssetValueLimit, "unit net value exceeded limit");
        uint256 entranceFee = _purchase(msg.sender, shareAmount, netAssetValue);
        // - update manager status
        updateFeeState(entranceFee.add(fee), netAssetValue);
    }

    /**
     * @dev Implementation of purchase.
     * @param trader           Address of user purchasing shares.
     * @param shareAmount      Amount of shares to purchase.
     * @param netAssetValue    NAV price used when purchasing.
     */
    function _purchase(address trader, uint256 shareAmount, uint256 netAssetValue)
        internal
        returns (uint256 entranceFee)
    {
        require(netAssetValue > 0, "nav must be greater than 0");
        require(shareAmount > 0, "amount must be greater than 0");
        // steps:
        // 1. get total asset value = tav
        // 2. nav = tav - streaming fee - performance fee
        // 3. collateral = nav * amount
        // 4. entrance fee = collateral * entrance fee
        // 5. collateral + entrance fee -> fund
        // 6. collateral -> perpetual
        // 6. streaming fee + performance fee + entrance fee -> maintainer

        // // raw total asset value
        // uint256 totalAssetValue = totalAssetValue();
        // // streaming fee, performance fee excluded
        // uint256 streamingFee = calculateStreamingFee(totalAssetValue);
        // totalAssetValue = totalAssetValue.sub(streamingFee);
        // uint256 performanceFee = calculatePerformanceFee(totalAssetValue);
        // totalAssetValue = totalAssetValue.sub(performanceFee);
        // collateral
        uint256 collateralRequired = netAssetValue.wmul(shareAmount);
        // entrance fee
        entranceFee = calculateEntranceFee(collateralRequired);
        // - pull collateral
        pullCollateral(trader, collateralRequired.add(entranceFee));
        // - update trader account status
        increaseShareBalance(trader, shareAmount);

        emit Purchase(trader, shareAmount, netAssetValue);
    }

    function requestToRedeem(uint256 shareAmount, uint256 slippage)
        external
        whenNotPaused
    {
        // steps:
        //  1. update redeeming amount in account
        //  2.. create order, push order to list

        require(shareAmount > 0, "amount must be greater than 0");
        require(slippage < LibConstant.RATE_UPPERBOUND, "slippage must be less then 100%");
        require(canRedeem(msg.sender), "cannot redeem now");
        // update user account
        increaseRedeemingAmount(msg.sender, shareAmount, slippage);
        emit RequestToRedeem(msg.sender, shareAmount, slippage);
    }

    function cancelRedeeming(uint256 shareAmount)
        external
        whenNotPaused
    {
        require(_redeemingBalances[msg.sender] > 0, "no share to redeem");
        decreaseRedeemingAmount(msg.sender, shareAmount);
        emit CancelRedeeming(msg.sender, shareAmount);
    }

    function takeRedeemingShare(
        address trader,
        uint256 shareAmount,
        uint256 priceLimit,
        LibTypes.Side side
    )
        external
        whenNotPaused
    {
        // order
        require(shareAmount <= _redeemingBalances[trader], "insufficient shares to take");
        // trading price and loss amount equivalent to slippage
        LibTypes.MarginAccount memory fundMarginAccount = marginAccount();
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
        ) = calculateTradingPrice(fundMarginAccount.side, slippage);
        validatePrice(side, tradingPrice, priceLimit);
        _perpetual.tradePosition(
            self(),
            msg.sender,
            redeemingSide,
            tradingPrice,
            redeemAmount
        );
        uint256 slippageValue = priceLoss.wmul(redeemAmount);
        redeem(trader, shareAmount, slippageValue);
    }

    function calculateFee()
        internal
        returns (uint256 assetValue, uint256 fee)
    {
        assetValue = totalAssetValue();
        // streaming fee, performance fee excluded
        uint256 streamingFee = calculateStreamingFee(assetValue);
        assetValue = assetValue.sub(streamingFee);
        uint256 performanceFee = calculatePerformanceFee(assetValue);

        assetValue = assetValue.sub(performanceFee);
        fee = streamingFee.add(performanceFee);
    }

    /**
     * @dev Redeem shares.
     */
    function redeem(address trader, uint256 shareAmount, uint256 slippageValue)
        internal
        whenNotPaused
    {
        // steps:
        //  1. calculate fee.
        //  2. caluclate fee excluded nav
        //  3. collateral return = nav * share amount
        //  4. push collateral -> user
        //  4. push fee -> maintainer
        // 6. streaming fee + performance fee -> maintainer

        require(shareAmount > 0, "amount must be greater than 0");
        // - calculate decreased amount
        (
            uint256 totalAssetValue,
            uint256 fee
        ) = calculateFee();
        uint256 netAssetValue = totalAssetValue.wdiv(_totalSupply);
        // note the loss amount is caused by slippage set by user.
        uint256 collateralToReturn = netAssetValue.wmul(shareAmount).sub(slippageValue);
        // - transfer balance
        // TODO: withdraw from perpetual
        _perpetual.withdrawFor(payable(self()), collateralToReturn);
        pushCollateral(payable(trader), collateralToReturn.sub(fee));
        decreaseRedeemingAmount(trader, shareAmount);
        decreaseShareBalance(trader, shareAmount);
        // - decrease total supply
        updateFeeState(fee, netAssetValue);

        emit Redeem(trader, netAssetValue, shareAmount);
    }

    function validatePrice(LibTypes.Side side, uint256 price, uint256 priceLimit) internal pure {
        if (side == LibTypes.Side.LONG) {
            require(price <= priceLimit, "price too high for long");
        } else {
            require(price >= priceLimit, "price too low for short");
        }
    }

    function calculateTradingPrice(LibTypes.Side side, uint256 slippage)
        internal
        returns (uint256 tradingPrice, uint256 priceLoss)
    {
        uint256 markPrice = _perpetual.markPrice();
        priceLoss = markPrice.wmul(slippage);
        tradingPrice = side == LibTypes.Side.LONG? markPrice.add(priceLoss): markPrice.sub(priceLoss);
    }
}