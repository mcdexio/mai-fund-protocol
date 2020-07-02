// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "../storage/Storage.sol";
import "../lib/LibCollateral.sol";
import "../lib/LibConstant.sol";
import "../lib/LibOrderbook.sol";
import "../lib/LibFundAccount.sol";
import "../lib/LibFundCore.sol";
import "../lib/LibFundProperty.sol";
import "../lib/LibFundFee.sol";
import "../lib/LibMathEx.sol";

import "./FundManagement.sol";

contract FundOperation is FundManagement {

    using SafeMath for uint256;
    using LibMathEx for uint256;
    using LibCollateral for LibCollateral.Collateral;
    using LibFundAccount for LibFundAccount.Account;
    using LibFundFee for LibFundCore.Core;
    using LibFundCore for LibFundCore.Core;
    using LibFundProperty for LibFundCore.Core;

    using LibOrderbook for LibOrderbook.ShareOrderbook;

    LibOrderbook.ShareOrderbook private _redeemingOrders;

    event Purchase(address indexed trader, uint256 netAssetValue, uint256 shareAmount);
    event RequestToRedeem(address indexed trader, uint256 shareAmount, uint256 slippage, uint256 orderId);
    event CancelRedeem(address indexed trader, uint256 orderId);
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
     * @dev Call once, when NAV is 0 (position size == 0).
     * @param shareAmount           Amount of shares to purchase.
     * @param initialNetAssetValue  Initial NAV defined by creator.
     */
    function initialize(uint256 shareAmount, uint256 initialNetAssetValue)
        external
        payable
    {
        require(shareAmount > 0, "share amount cannot be 0");
        // TODO: create condition
        require(_core.shareTotalSupply == 0, "share supply is not 0");
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
        uint256 totalAssetValue = _core.totalAssetValue();
        // streaming fee, performance fee excluded
        uint256 streamingFee = _core.calculateStreamingFee(totalAssetValue);
        totalAssetValue = totalAssetValue.sub(streamingFee);
        uint256 performanceFee = _core.calculatePerformanceFee(totalAssetValue);
        totalAssetValue = totalAssetValue.sub(performanceFee);
        uint256 netAssetValue = totalAssetValue.wdiv(_core.shareTotalSupply);

        require(netAssetValue <= netAssetValueLimit, "unit net value exceeded limit");
        uint256 entranceFee = _purchase(msg.sender, shareAmount, netAssetValue);
        // - update manager status
        _core.updateFeeState(entranceFee.add(streamingFee).add(performanceFee), netAssetValue);
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
        // uint256 totalAssetValue = _core.totalAssetValue();
        // // streaming fee, performance fee excluded
        // uint256 streamingFee = _core.calculateStreamingFee(totalAssetValue);
        // totalAssetValue = totalAssetValue.sub(streamingFee);
        // uint256 performanceFee = _core.calculatePerformanceFee(totalAssetValue);
        // totalAssetValue = totalAssetValue.sub(performanceFee);
        // collateral
        uint256 collateralRequired = netAssetValue.wmul(shareAmount);
        // entrance fee
        entranceFee = _core.calculateEntranceFee(collateralRequired);
        // - pull collateral
        _core.collateral.pullCollateral(trader, collateralRequired.add(entranceFee));
        // - update trader account status
        _core.accounts[trader].increaseShareBalance(shareAmount);
        // - update total supply
        _core.shareTotalSupply = _core.shareTotalSupply.add(shareAmount);

        emit Purchase(trader, shareAmount, netAssetValue);
    }

    function createRedeemingOrder(address trader, uint256 shareAmount, uint256 slippage)
        internal
        returns (LibOrderbook.ShareOrder memory newOrder)
    {
        newOrder = LibOrderbook.ShareOrder({
            id: _redeemingOrders.getNextId(),
            index: 0,
            trader: trader,
            filled: 0,
            amount: shareAmount,
            slippage: slippage,
            availableAt: LibUtils.currentTime().add(_core.configuration.minimalRedeemingPeriod)
        });
    }

    function requestToRedeem(uint256 shareAmount, uint256 slippage)
        external
        whenNotPaused
    {
        // steps:
        //  1. update redeeming amount in account
        //  2.. create order, push order to list

        require(shareAmount > 0, "amount must be greater than 0");
        require(slippage < LibConstant.UNSIGNED_ONE.mul(100), "slippage must be less then 100%");
        require(_core.accounts[msg.sender].canRedeem(_core.configuration.withdrawPeriod), "cannot withdraw now");
        // update user account
        _core.accounts[msg.sender].increaseRedeemingAmount(shareAmount);
        // push new order to list
        LibOrderbook.ShareOrder memory newOrder = createRedeemingOrder(msg.sender, shareAmount, slippage);
        _redeemingOrders.add(newOrder);

        emit RequestToRedeem(msg.sender, shareAmount, slippage, newOrder.id);
    }

    function cancelRedeem(uint256 id)
        external
        whenNotPaused
    {
        require(_redeemingOrders.has(id), "order id not exist");
        LibOrderbook.ShareOrder memory order = _redeemingOrders.getOrder(id);
        require(order.trader == msg.sender, "not owner of order");
        _core.accounts[msg.sender].decreaseRedeemingAmount(order.amount);
        _redeemingOrders.remove(id);

        emit CancelRedeem(msg.sender, id);
    }

    /**
     * @dev Redeem shares.
     */
    function redeem(address payable trader, uint256 shareAmount, uint256 lossValue)
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
        _core.accounts[trader].redeem(shareAmount);

        uint256 totalAssetValue = _core.totalAssetValue();
        // streaming fee, performance fee excluded
        uint256 streamingFee = _core.calculateStreamingFee(totalAssetValue);
        totalAssetValue = totalAssetValue.sub(streamingFee);
        uint256 performanceFee = _core.calculatePerformanceFee(totalAssetValue);
        totalAssetValue = totalAssetValue.sub(performanceFee);

        uint256 netAssetValue = totalAssetValue.wdiv(_core.shareTotalSupply);
        // note the loss amount is caused by slippage set by user.
        uint256 collateralToReturn = netAssetValue.wmul(shareAmount).sub(lossValue);
        // - transfer balance
        // TODO: withdraw from perpetual
        _core.collateral.pushCollateral(trader, collateralToReturn);
        // - increase total supply
        _core.shareTotalSupply = _core.shareTotalSupply.sub(shareAmount);

        emit Redeem(trader, netAssetValue, shareAmount);
    }

    function takeRedeemOrder(
        uint256 id,
        uint256 shareAmount,
        uint256 priceLimit,
        LibTypes.Side expectedSide
    )
        external
        whenNotPaused
    {
        require(_redeemingOrders.has(id), "order id not exist");

        // order
        LibOrderbook.ShareOrder memory order = _redeemingOrders.getOrder(id);
        require(order.amount.sub(order.filled) >= shareAmount, "not enough amount to fill");
        require(order.availableAt < LibUtils.currentTime(), "order not available now");

        // trading price and loss amount equivalent to slippage
        LibTypes.MarginAccount memory fundMarginAccount = _core.perpetual.getMarginAccount(address(this));
        require(fundMarginAccount.side == expectedSide, "not expected side");
        (
            uint256 tradingPrice,
            uint256 priceLoss
        ) = calculateTradingPrice(fundMarginAccount.side, order.slippage);
        if (expectedSide == LibTypes.Side.LONG) {
            require(tradingPrice <= priceLimit, "price too high for long");
        } else {
            require(tradingPrice >= priceLimit, "price too low for short");
        }
        //
        uint256 redeemPercentage = shareAmount.wdiv(_core.shareTotalSupply);
        // TODO: align to tradingLotSize
        uint256 redeemAmount = fundMarginAccount.size.wmul(redeemPercentage);
        LibTypes.Side redeemingSide = fundMarginAccount.side == LibTypes.Side.LONG?
            LibTypes.Side.SHORT : LibTypes.Side.LONG;
        _core.perpetual.tradePosition(
            address(this),
            msg.sender,
            redeemingSide,
            tradingPrice,
            redeemAmount
        );
        uint256 lossValue = priceLoss.wmul(redeemAmount);
        redeem(payable(order.trader), shareAmount, lossValue);
    }

    function calculateTradingPrice(LibTypes.Side side, uint256 slippage)
        internal
        returns (uint256 tradingPrice, uint256 priceLoss)
    {
        uint256 markPrice = _core.perpetual.markPrice();
        priceLoss = markPrice.wmul(slippage);
        tradingPrice = side == LibTypes.Side.LONG? markPrice.add(priceLoss): markPrice.sub(priceLoss);
    }
}