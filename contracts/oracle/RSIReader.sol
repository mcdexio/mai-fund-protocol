// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";

import "../lib/LibConstant.sol";
import "../lib/LibMathEx.sol";

interface IPriceSeriesRetriever {
    function retrievePriceSeries(
        uint256 span,
        uint256 beginIndex,
        uint256 endIndex
    ) external view returns (uint256[] memory series);
}

contract RSIReader {

    using SafeMath for uint256;
    using LibMathEx for uint256;

    uint256 public constant BALANCED_RSI = 10 ** 18 * 50;
    uint256 public constant RSI_LOWERBOUND = 0;
    uint256 public constant RSI_UPPERBOUND = 10 ** 18 * 100;

    IPriceSeriesRetriever internal _priceSeriesRetriever;

    // configurations
    uint256 internal _period;
    uint256 internal _numPeriod;
    uint256 internal _totalPeriod;

    event SetPeriod(uint256 oldValue, uint256 newValue);
    event SetNumPeriod(uint256 oldValue, uint256 newValue);

    constructor(address priceSeriesRetriever, uint256 period, uint256 numPeriod) internal {
        require(priceSeriesRetriever != address(0), "invalid price reader");
        require(Address.isContract(priceSeriesRetriever), "price reader must be contract");
        require(period > 0, "period must be greater than 0");
        require(numPeriod > 0, "num period must be greater than 0");

        _period = period;
        _numPeriod = numPeriod;
        _priceSeriesRetriever = IPriceSeriesRetriever(priceSeriesRetriever);
        _totalPeriod = period.mul(numPeriod);
    }

    function period() public view returns (uint256) {
        return _period;
    }

    function numPeriod() public view returns (uint256) {
        return _numPeriod;
    }

    function getCurrentRSI() public view returns (uint256) {
        uint256[] memory priceSeries = _priceSeriesRetriever.retrievePriceSeries(
            _period,
            _now().sub(_totalPeriod),
            _now()
        );
        require(priceSeries.length > 0, "no price data");
        return _calculateRSI(priceSeries);
    }

    function _calculateRSI(uint256[] memory prices) internal pure returns (uint256) {
        require(prices.length > 0, "no price to be calculated");
        uint256 accumulativeGain;
        uint256 accumulativeLoss;
        uint256 lastNonZeroPrice;
        for (uint256 i = 1; i < prices.length; i++) {
            uint256 current = prices[i];
            uint256 previous = prices[i - 1];
            require(current != 0 && previous != 0, "invalid price from feeder");
            if (current > previous) {
                accumulativeGain = accumulativeGain.add(current.sub(previous));
            } else if (current < previous) {
                accumulativeLoss = accumulativeLoss.add(previous.sub(current));
            }
            lastNonZeroPrice = current;
        }
        if (accumulativeGain == accumulativeLoss) {
            return BALANCED_RSI;
        }
        return RSI_UPPERBOUND.wmul(accumulativeGain)
            .wdiv(accumulativeGain.add(accumulativeLoss));
    }

    function _now() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}