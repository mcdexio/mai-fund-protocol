// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SignedSafeMath.sol";

import "../../lib/LibTypes.sol";
import "../../lib/LibMathEx.sol";
import "../Core.sol";
import "../Getter.sol";

interface ITradingStrategy {
    function getNextTarget() external returns (int256);
}

contract AutoTradingFund is
    Initializable,
    Core,
    Getter
{
    using Math for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using LibMathEx for int256;
    using LibMathEx for uint256;
    using LibTypes for LibTypes.Side;

    bool internal _inversed;
    ITradingStrategy internal _strategy;
    uint256 internal _rebalancingSlippage;
    uint256 internal _rebalancingTolerance;

    event Rebalance(LibTypes.Side side, uint256 price, uint256 amount);

    function initialize(
        string calldata name,
        string calldata symbol,
        uint8 collateralDecimals,
        address perpetual,
        uint256 cap,
        address strategy,
        bool inversed
    )
        external
        initializer
    {
        __Core_init(name, symbol, collateralDecimals, perpetual, cap);
        __AutoTradingFund_init_unchained(strategy, inversed);
    }

    function __AutoTradingFund_init_unchained(
        address strategy,
        bool inversed
    )
        internal
        initializer
    {
        _strategy = ITradingStrategy(strategy);
        _inversed = inversed;
    }

    /**
     * @notice  Return true if underlaying perpetual of fund is inversed.
     */
    function inversed()
        external
        view
        returns (bool)
    {
        return _inversed;
    }

    /**
     * @notice  Return address of current strategy.
     */
    function strategy()
        external
        view
        returns (address)
    {
        return address(_strategy);
    }

    /**
     * @notice  Return slippage of rebalancing.
     */
    function rebalancingSlippage()
        external
        view
        returns (uint256)
    {
        return _rebalancingSlippage;
    }

    /**
     * @notice  Return tolerance of rebalancing (leverage).
     *          Eg, target is 1.1, current is 1.
     *          If tolerance < 0.1, it means no rebalancing can be triggered right now.
     */
    function rebalancingTolerance()
        external
        view
        returns (uint256)
    {
        return _rebalancingTolerance;
    }

    /**
     * @notice  Set slippage and tolerance of rebalancing.
     */
    function setParameter(bytes32 key, int256 value)
        public
        virtual
        override
        onlyOwner
    {
        if (key == "rebalancingSlippage") {
            _rebalancingSlippage = value.toUint256();
        } else if (key == "rebalancingTolerance") {
            _rebalancingTolerance = value.toUint256();
        }
        super.setParameter(key, value);
    }

    /**
     * @notice  Return true if rebalance is needed.
     */
    function needRebalancing() public returns (bool) {
        int256 nextTarget = _nextTarget();
        int256 currentleverage = leverage();
        return currentleverage.sub(nextTarget).abs().toUint256() > _rebalancingTolerance;
    }

    /**
     * @notice  Rebalance current position to target leverage.
     * @param   maxPositionAmount   Max amount of underlaying position caller want to take (align to lotsize)
     * @param   priceLimit          Max price of underlaying position.
     * @param   side                Expected side of underlaying positon.
     */
    function rebalance(uint256 maxPositionAmount, uint256 priceLimit, LibTypes.Side side)
        external
        whenNotPaused
        whenNotStopped
    {
        require(maxPositionAmount > 0, "amount is 0");
        require(needRebalancing(), "need no rebalance");
        (
            uint256 rebalancingAmount,
            LibTypes.Side rebalancingSide
        ) = calculateRebalancingTarget();
        require(rebalancingAmount > 0 && rebalancingSide != LibTypes.Side.FLAT, "need no rebalance");
        require(rebalancingSide == side, "unexpected side");

        ( uint256 tradingPrice, ) = _biddingPrice(rebalancingSide, _rebalancingSlippage);
        uint256 tradingAmount = Math.min(maxPositionAmount, rebalancingAmount);
        _validatePrice(rebalancingSide, tradingPrice, priceLimit);
        // to reuse _tradePosition, we have to swap taker and maker then take the counterSide
        _tradePosition(_self(), _msgSender(), rebalancingSide, tradingPrice, tradingAmount);
        emit Rebalance(rebalancingSide, tradingPrice, tradingAmount);
    }

    /**
     * @notice  Get amount / side to rebalance.
     *          To compact with _tradePosition, side is reversed.
     *          delta is, eg:
     *           - expected = 1,  current = 1  -->  no adjust
     *           - expected = 2,  current = 1  -->  2 -  1 =  1,   LONG for 1
     *           - expected = 0,  current = 1  -->  0 -  1 = -1,   SHORT for 1
     *           - expected = 0,  current = -1  -->  0 -  -1 = 1,   LONG for 1
     *           - expected = -1, current = 1  --> -1 -  1 = -2,   SHORT for 2
     *           - expected = 2,  current = -1 -->  2 - -1 =  3,   LONG for 3
     *           - expected = -2, current = -1 --> -2 - -1 = -1,   SHORT for 1
     *           ...
     * @return  amount  Amount of positions needed for rebalancing to target leverage.
     * @return  side    Side of positions needed for rebalancing to target leverage.
     */
    function calculateRebalancingTarget()
        public
        returns (uint256 amount, LibTypes.Side side)
    {
        uint256 markPrice = _markPrice();
        require(markPrice != 0, "mark price is 0");

        int256 signedSize = _signedSize();    // -40000
        int256 nextTarget = _nextTarget();    // -40000 - 40000

        int256 expectedMarginBalance = _netAssetValue().toInt256().wmul(nextTarget);
        int256 expectedSize = expectedMarginBalance.wdiv(markPrice.toInt256());
        int256 target = expectedSize.sub(signedSize);
        amount = target.abs().toUint256();

        if (amount == 0) {
            side = LibTypes.Side.FLAT;
        } else {
            side = target > 0? LibTypes.Side.LONG: LibTypes.Side.SHORT;
        }
    }

    /**
     * @dev     Add a sign for side of fund margin, LONG is positive while SHORT is negative.
     */
    function _signedSize()
        internal
        view
        returns (int256)
    {
        LibTypes.MarginAccount memory fundMarginAccount = _marginAccount();
        int256 size = fundMarginAccount.size.toInt256();
        return fundMarginAccount.side == LibTypes.Side.SHORT? size.neg(): size;
    }

    /**
     * @dev     Get next target from oracle.
     */
    function _nextTarget()
        internal
        returns (int256)
    {
        int256 nextTarget = _strategy.getNextTarget();
        // inverse contract
        if (_inversed) {
            return nextTarget.neg();
        }
        return nextTarget;
    }

    uint256[16] private __gap;
}
