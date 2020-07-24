// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../../lib/LibTypes.sol";
import "../../lib/LibUtils.sol";
import "../../lib/LibMathEx.sol";
import "../../storage/FundStorage.sol";
import "../FundBase.sol";
import "../FundManagement.sol";

interface ITradingStrategy {
    function getNextTarget() external returns (int256);
}

contract AutoTraderFund is
    FundStorage,
    FundBase,
    FundManagement
{

    using Math for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using LibMathEx for int256;
    using LibMathEx for uint256;

    uint256 internal _inversed;
    uint256 internal _rebalancingSlippage;
    uint256 internal _rebalancingTolerance;

    function needRebalancing() public returns (bool) {
        int256 nextTarget = getNextTarget();
        int256 currentleverage = getLeverage();
        return currentleverage.sub(nextTarget).abs().toUint256() > _rebalancingTolerance;
    }

    function rebalance(uint256 maxPositionAmount, uint256 limitPrice, LibTypes.Side side)
        external
    {
        require(maxPositionAmount > 0, "position amount must greater than 0");
        require(needRebalancing(), "no need to rebalance");
        (
            uint256 rebalancingAmount,
            LibTypes.Side rebalancingSide
        ) = calculateRebalancingTarget();
        require(rebalancingAmount > 0 && rebalancingSide != LibTypes.Side.FLAT, "no need to rebalance");
        require(rebalancingSide == side, "unexpected side");

        ( uint256 tradingPrice, ) = getBiddingPrice(rebalancingSide, _rebalancingSlippage);
        uint256 tradingAmount = Math.min(maxPositionAmount, rebalancingAmount);
        validateBiddingPrice(rebalancingSide, tradingPrice, limitPrice);
        _perpetual.tradePosition(
            self(),
            msg.sender,
            rebalancingSide,
            tradingPrice,
            tradingAmount
        );
    }

    function getSignedSize()
        public
        view
        returns (int256)
    {
        LibTypes.MarginAccount memory fundMarginAccount = getMarginAccount();
        int256 size = fundMarginAccount.size.toInt256();
        return fundMarginAccount.side == LibTypes.Side.SHORT? size.neg(): size;
    }

    function calculateRebalancingTarget()
        public
        returns (uint256 amount, LibTypes.Side side)
    {
        uint256 markPrice = _perpetual.markPrice();
        require(markPrice != 0, "mark price cannot be 0");

        int256 signedSize = getSignedSize();    // -40000
        int256 nextTarget = getNextTarget();    // -40000 - 40000

        (uint256 netAssetValue, ) = getNetAssetValueAndFee();
        int256 expectedMarginBalance = netAssetValue.toInt256().wmul(nextTarget);
        int256 expectedSize = expectedMarginBalance.wdiv(markPrice.toInt256());
        // delta is, eg:
        //  - expected = 1,  current = 1  -->  no adjust
        //  - expected = 2,  current = 1  -->  2 -  1 =  1,   LONG for 1
        //  - expected = 0,  current = 1  -->  0 -  1 = -1,   SHORT for 1
        //  - expected = 0,  current = -1  -->  0 -  -1 = 1,   LONG for 1
        //  - expected = -1, current = 1  --> -1 -  1 = -2,   SHORT for 2
        //  - expected = 2,  current = -1 -->  2 - -1 =  3,   LONG for 3
        //  - expected = -2, current = -1 --> -2 - -1 = -1,   SHORT for 1
        //  ....
        int256 target = expectedSize.sub(signedSize);
        amount = target.abs().toUint256();
        if (amount == 0) {
            side = LibTypes.Side.FLAT;
        } else {
            side = target > 0? LibTypes.Side.LONG: LibTypes.Side.SHORT;
        }
    }

    function getNextTarget()
        internal
        returns (int256)
    {
        int256 nextTarget = ITradingStrategy(_manager).getNextTarget();
        // inverse contract
        if (_collateral == address(0)) {
            return nextTarget.neg();
        }
        return nextTarget;
    }
}
