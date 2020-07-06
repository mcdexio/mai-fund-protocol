// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../../external/LibTypes.sol";
import "../../lib/LibFundCore.sol";
import "../../lib/LibUtils.sol";
import "../../lib/LibMathEx.sol";

import "../FundBase.sol";

interface ITradingStrategy {
    function getNextTarget() external view returns (int256);
}

contract AutoTraderFund is FundBase {

    using Math for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using LibMathEx for int256;
    using LibMathEx for uint256;

    ITradingStrategy private _strategy;
    bool private _rebalancingDone = true;
    int256 private _lastLeverageTarget;
    uint256 private _lastRebalancingTime;
    uint256 private _rebalancingPositionAmount;
    LibTypes.Side private _rebalancingSide;
    uint256 private _slippage;
    uint256 private _leverageTolerance;

    constructor(address strategy) public {
        _strategy = ITradingStrategy(strategy);
    }

    function isRebalanceRequired() public returns (bool) {
        int256 nextLeverageTarget = _strategy.getNextTarget();
        // stratege outputs a different target
        if (nextLeverageTarget != _lastLeverageTarget) {
            return true;
        }
        //  deviate from last target
        int256 currentleverage = _core.leverage().toInt256();
        return currentleverage.sub(_lastLeverageTarget).abs().toUint256() > _leverageTolerance;
    }

    function takeRebalanceOrder(uint256 maxPositionAmount, uint256 limitPrice, LibTypes.Side side)
        external
    {
        require(_rebalancingPositionAmount > 0, "not position to take now");
        require(side == _rebalancingSide, "not expected side");
        require(maxPositionAmount > 0, "position amount must greater than 0");
        require(maxPositionAmount <= _rebalancingPositionAmount, "insufficient amount");

        uint256 tradingAmount = Math.min(maxPositionAmount, _rebalancingPositionAmount);
        uint256 tradingPrice = _core.perpetual.markPrice();
        uint256 priceSlippage = tradingPrice.wmul(_slippage);
        if (_rebalancingSide == LibTypes.Side.LONG) {
            tradingPrice = tradingPrice.sub(priceSlippage);
            require(tradingPrice <= limitPrice, "price too high for long");
        } else {
            tradingPrice = tradingPrice.add(priceSlippage);
            require(tradingPrice >= limitPrice, "price too low for short");
        }
        _core.perpetual.tradePosition(
            address(this),
            msg.sender,
            _rebalancingSide,
            tradingPrice,
            tradingAmount
        );
        _rebalancingPositionAmount = _rebalancingPositionAmount.sub(tradingAmount);

        if (_rebalancingPositionAmount == 0) {
            _rebalancingSide = LibTypes.Side.FLAT;
            _rebalancingDone = true;
        }
    }

    function requestToRebalance() external {
        require(_rebalancingDone, "last rebalancing is not done yet");
        require(isRebalanceRequired(), "no need to rebalance now");
        int256 amountToRebalance = getAmountToRebalance();
        if (amountToRebalance == 0) {
            return;
        }
        _rebalancingPositionAmount = amountToRebalance.abs().toUint256();
        _rebalancingSide = amountToRebalance > 0? LibTypes.Side.LONG: LibTypes.Side.SHORT;
        _rebalancingDone = false;
        _lastRebalancingTime = LibUtils.currentTime();
    }

    function getAmountToRebalance() internal returns (int256) {
        uint256 markPrice = _core.perpetual.markPrice();
        require(markPrice != 0, "mark price cannot be 0");
        int256 nextTarget = _strategy.getNextTarget();
        LibTypes.MarginAccount memory marginAccount = _core.perpetual.getMarginAccount(address(this));
        int256 marginBalance = _core.perpetual.marginBalance(address(this));
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
        return expectedSize.sub(marginAccount.size.toInt256());
    }
}
