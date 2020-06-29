pragma solidity 0.6.10;

import "../TraderBase.sol";
import "../../lib/LibFundStorage.sol";
import "../../lib/LibFundUtils.sol";

interface ITradingStrategy {
    function getNextTarget() external returns (int256);
}

contract AutoTrader is TraderBase, Fund {

    uint256 public TIMESPAN_RESOLUTION_SECONDS = 5*60;

    int256 private _lastTarget;
    uint256 private _lastRebalancingTime;
    ITradingStrategy _strategy;

    uint256 private _rebalancingDone = true;
    uint256 private _rebalancingPositionAmount;
    uint256 private _rebalancingSide;
    uint256 private _slippage;

    constructor(address strategy) public {
        _lastTarget = ITradingStrategy(strategy);
    }

    function isRebalanceRequired() public view returns (bool) {
        leverage = _fundStorage.getLeverage();
        return _lastTarget != _strategy.getNextTarget() || leverage;
    }

    function takeRebalanceOrder(uint256 limitPrice, uint256 side, uint256 maxPositionAmount)
        external
    {
        require(_rebalancingPositionAmount > 0, "not position to take now");
        require(side == _rebalancingSide.CounterSide(), "not expected side");
        require(maxPositionAmount > 0, "position amount must greater than 0");

        uint256 tradingAmount = min(_rebalancingPositionAmount, maxPositionAmount);
        uint256 tradingPrice = _fundStorage.perpetual.markPrice();`
        if (_rebalancingSide == Side.LONG) {
            tradingPrice = tradingPrice.wmul(ONE.sub(_slippage));
        } else {
            tradingPrice = tradingPrice.wmul(ONE.add(_slippage));
        }
        perpetual.trade(
            this.address,
            msg.sender,
            _rebalancingSide,
            tradingPrice,
            tradingAmount
        );

        _rebalancingPositionAmount = _rebalancingPositionAmount.sub(tradingAmount);
        if (_rebalancingPositionAmount == 0) {
            _rebalancingSide = Side.FLAT;
            _rebalancingDone = true;
        }
    }

    function requestToRebalance() external {
        require(_rebalancingDone, "last rebalancing is not done yet")
        require(
            _lastRebalancingTime.add(TIME_SPAN_RESOLUTION_SECONDS) < LibUtils.currentTime(),
            "rebalance too frequent"
        );
        require(isRebalanceRequired(), "no need to rebalance now");
        int256 amountToRebalance = getAmountToRebalance();
        if (amountToRebalance == 0) {
            return;
        }
        _rebalancingPositionAmount = amountToRebalance.abs();
        if (amountToRebalance > 0) {
            _rebalancingSide = Side.LONG;
        } else {
            _rebalancingSide = Side.SHORT;
        }
        _rebalancingDone = false;
        _lastRebalancingTime = LibFundUtils.currentTime();
    }

    function getAmountToRebalance() internal view returns (uint256) {
        uint256 markPrice = _fundStorage.perpetual.markPrice();
        require(markPrice != 0, "mark price cannot be 0");
        int256 nextTarget = _strategy.getNextTarget();
        MarginAccount memory marginAccount = _fundStorage.perpetual.getMarginAccount();
        int256 marginBalance = _fundStorage.perpetual.marginBalance(this.address);
        int256 expectedMargin = marginBalance.wmul(nextTarget);
        int256 expectedSize = expectedMargin.wdiv(markPrice);
        // delta is, eg:
        //  - expected = 1,  current = 1  -->  no adjust
        //  - expected = 2,  current = 1  -->  2 -  1 =  1,   LONG for 1
        //  - expected = 0,  current = 1  -->  0 -  1 = -1,   SHORT for 1
        //  - expected = -1, current = 1  --> -1 -  1 = -2,   SHORT for 2
        //  - expected = 2,  current = -1 -->  2 - -1 =  3,   LONG for 3
        //  - expected = -2, current = -1 --> -2 - -1 = -1,   SHORT for 1
        //  ....
        return expectedSize.sub(marginAccount.size);
    }
}
