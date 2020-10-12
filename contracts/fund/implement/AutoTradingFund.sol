// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";

import "../../lib/LibTypes.sol";
import "../../lib/LibMathEx.sol";
import "../../lib/LibTargetCalculator.sol";
import "../SettleableFund.sol";
import "../Getter.sol";

interface ITradingStrategy {
    function getNextTarget() external returns (int256);
}

contract AutoTradingFund is
    Initializable,
    SettleableFund,
    Getter
{
    using Math for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using LibMathEx for uint256;
    using LibTypes for LibTypes.Side;

    bool internal _inversed;
    ITradingStrategy internal _strategy;
    uint256 internal _rebalanceSlippage;
    uint256 internal _rebalanceTolerance;

    event Rebalance(LibTypes.Side side, uint256 price, uint256 amount);

    function initialize(
        string calldata tokenName,
        string calldata tokenSymbol,
        uint8 collateralDecimals,
        address perpetualAddress,
        uint256 tokenCap,
        address strategyAddress,
        bool inversedContract
    )
        external
        initializer
    {
        __SettleableFund_init(tokenName, tokenSymbol, collateralDecimals, perpetualAddress, tokenCap);
        __AutoTradingFund_init_unchained(strategyAddress, inversedContract);
    }

    function __AutoTradingFund_init_unchained(
        address strategyAddress,
        bool inversedContract
    )
        internal
        initializer
    {
        require(strategyAddress != address(0), "invalid strategy");
        require(Address.isContract(strategyAddress), "strategy must be contract");
        _strategy = ITradingStrategy(strategyAddress);
        _inversed = inversedContract;
    }

    function description()
        external
        view
        returns (address strategy, bool inversed, uint256 rebalanceSlippage, uint256 rebalanceTolerance)
    {
        strategy = address(_strategy);
        inversed = _inversed;
        rebalanceSlippage = _rebalanceSlippage;
        rebalanceTolerance = _rebalanceTolerance;
    }

    /**
     * @notice  Set slippage and tolerance of rebalance.
     */
    function setParameter(bytes32 key, int256 value)
        public
        virtual
        override
        onlyOwner
    {
        if (key == "rebalanceSlippage") {
            _rebalanceSlippage = value.toUint256();
        } else if (key == "rebalanceTolerance") {
            _rebalanceTolerance = value.toUint256();
        } else {
            super.setParameter(key, value);
            return;
        }
        emit SetParameter(key, value);
    }

    /**
     * @notice  Return true if rebalance is needed.
     */
    function rebalanceTarget()
        public
        returns (bool needRebalance, uint256 amount, LibTypes.Side side)
    {
        uint256 currentNetAssetValue = _updateNetAssetValue();
        int256 nextTargetLeverage = _nextTargetLeverage();
        int256 currentLeverage = _leverage(currentNetAssetValue);
        needRebalance = currentLeverage.sub(nextTargetLeverage).abs().toUint256() >= _rebalanceTolerance;
        if (needRebalance) {
            ( amount, side ) = LibTargetCalculator.calculateRebalanceTarget(
                _perpetual,
                currentNetAssetValue,
                nextTargetLeverage
            );
        }
    }

    /**
     * @notice  Rebalance current position to target leverage.
     *
     *          !!! Though this methods looks like `bidRedeemingShare` in BaseFund, they are quite different things.
     *          Side parameter in this method represents the FUND's trading direction, not the caller's.
     *
     * @param   maxPositionAmount   Max amount of underlaying position caller want to take (align to lotsize)
     * @param   priceLimit          Max price of underlaying position.
     * @param   side                Expected side of underlaying positon.
     */
    function rebalance(uint256 maxPositionAmount, uint256 priceLimit, LibTypes.Side side)
        external
        whenNotPaused
        whenInState(FundState.Normal)
    {
        require(maxPositionAmount > 0, "amount is 0");
        (
            bool needRebalance,
            uint256 targetAmount,
            LibTypes.Side targetSide
        ) = rebalanceTarget();
        require(needRebalance, "need no rebalance");
        require(targetSide == side, "unexpected side");
        uint256 tradingAmount = Math.min(maxPositionAmount, targetAmount);
        ( uint256 tradingPrice, ) = _biddingPrice(LibTypes.opposite(targetSide), priceLimit, _rebalanceSlippage);
        _tradePosition(_self(), _msgSender(), targetSide, tradingPrice, tradingAmount);
        emit Rebalance(targetSide, tradingPrice, tradingAmount);
    }

    /**
     * @dev     Get next target from oracle.
     */
    function _nextTargetLeverage()
        internal
        returns (int256)
    {
        int256 nextTargetLeverage = _strategy.getNextTarget();
        if (_inversed) {
            return nextTargetLeverage.neg();
        }
        return nextTargetLeverage;
    }

    uint256[16] private __gap;
}
