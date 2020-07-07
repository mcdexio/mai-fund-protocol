// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../../external/LibTypes.sol";
import "../../lib/LibUtils.sol";
import "../../lib/LibMathEx.sol";
import "../../storage/FundStorage.sol";
import "../FundBase.sol";

interface ITradingStrategy {
    function getNextTarget() external view returns (int256);
}

contract AutoTraderFund is FundStorage, FundBase {

    using Math for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using LibMathEx for int256;
    using LibMathEx for uint256;

    uint256 internal _rebalancingSlippage;
    uint256 internal _rebalancingTolerance;

    function needRebalancing() public returns (bool) {
        int256 nextTarget = getNextTarget();
        //  deviate from last target
        int256 currentleverage = leverage().toInt256();
        return currentleverage.sub(nextTarget).abs().toUint256() > _rebalancingTolerance;
    }

    function takeRebalanceOrder(uint256 maxPositionAmount, uint256 limitPrice, LibTypes.Side side)
        external
    {
        require(needRebalancing(), "no need to rebalance");
        (
            uint256 rebalancingAmount,
            LibTypes.Side rebalancingSide
        ) = calculateRebalancingTarget();
        require(rebalancingAmount > 0, "no amount to rebalance");
        require(rebalancingSide == side, "unexpected side");
        require(maxPositionAmount > 0, "position amount must greater than 0");

        ( uint256 tradingPrice, ) = calculateTradingPrice(rebalancingSide, _rebalancingSlippage);
        uint256 tradingAmount = Math.min(maxPositionAmount, rebalancingAmount);
        validatePrice(rebalancingSide, tradingPrice, limitPrice);
        _perpetual.tradePosition(
            self(),
            msg.sender,
            rebalancingSide,
            tradingPrice,
            tradingAmount
        );
    }

    function getNextTarget() internal view returns (int256) {
        int256 nextTarget = ITradingStrategy(_maintainer).getNextTarget();
        // TODO: validate range of next target.
        return nextTarget;
    }

    function calculateRebalancingTarget()
        internal
        returns (uint256 amount, LibTypes.Side side)
    {
        uint256 markPrice = _perpetual.markPrice();
        require(markPrice != 0, "mark price cannot be 0");

        LibTypes.MarginAccount memory fundMarginAccount = marginAccount();
        int256 positionSize = fundMarginAccount.size.toInt256();
        int256 marginBalance = totalAssetValue().toInt256();
        int256 nextTarget = getNextTarget();
        int256 expectedMargin = marginBalance.wmul(nextTarget);
        int256 expectedSize = expectedMargin.wdiv(markPrice.toInt256());
        // delta is, eg:
        //  - expected = 1,  current = 1  -->  no adjust
        //  - expected = 2,  current = 1  -->  2 -  1 =  1,   LONG for 1
        //  - expected = 0,  current = 1  -->  0 -  1 = -1,   SHORT for 1
        //  - expected = -1, current = 1  --> -1 -  1 = -2,   SHORT for 2
        //  - expected = 2,  current = -1 -->  2 - -1 =  3,   LONG for 3
        //  - expected = -2, current = -1 --> -2 - -1 = -1,   SHORT for 1
        //  ....
        int256 target = expectedSize.sub(positionSize);
        amount = target.abs().toUint256();
        side = target > 0? LibTypes.Side.LONG: LibTypes.Side.SHORT;
    }
}
