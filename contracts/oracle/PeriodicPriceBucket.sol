// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "../lib/LibEnumerableMap.sol";
import "../lib/LibUtils.sol";

interface IPriceFeeder {
    function price() external view returns (uint256 lastPrice, uint256 lastTimestamp);
}

contract PeriodicPriceBucket is Ownable {

    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using LibEnumerableMap for LibEnumerableMap.AppendOnlyUintToUintMap;

    uint256 public constant MAX_BUCKETS = 32;

    IPriceFeeder internal _priceFeeder;
    // period => period index => price
    EnumerableSet.UintSet internal _periods;
    mapping(uint256 => uint256) internal _firstPeriodIndexes;
    // timespan index => price
    mapping(uint256 => LibEnumerableMap.AppendOnlyUintToUintMap) internal _buckets;

    event FirstIndex(uint256 period, uint256 periodIndex);
    event UpdatePrice(address indexed feeder, uint256 price, uint256 timestamp, uint256 priceIndex);
    event AddBucket(uint256 period);
    event RemoveBucket(uint256 period);

    constructor(address priceFeeder) public {
        _priceFeeder = IPriceFeeder(priceFeeder);
    }

    /**
     * @notice  Add time bucket, no duplication.
     * @param   period  Period of bucket to be added.
     */
    function addBucket(uint256 period)
        external
        onlyOwner
    {
        require(period > 0, "period must be greater than 0");
        require(_periods.length() < MAX_BUCKETS, "number of buckets reaches limit");
        require(_periods.add(period), "period is duplicated");
        emit AddBucket(period);
    }

    /**
     * @notice  Remove time bucket.
     * @param   period  Period of bucket to be removed.
     */
    function removeBucket(uint256 period)
        external
        onlyOwner
    {
        require(_periods.remove(period), "period is not exist");
        delete _buckets[period];
        delete _firstPeriodIndexes[period];
        emit RemoveBucket(period);
    }

    /**
     * @notice  Read price from oracle, update all buckets.
     *          The latest price in a bucket will overwrite price in the same segment.
     */
    function updatePrice()
        external
    {
        require(address(_priceFeeder) != address(0), "no price feeder set");
        (
            uint256 newPrice,
            uint256 newTimestamp
        ) =  _priceFeeder.price();
        for (uint256 i = 0; i < _periods.length(); i++) {
            uint256 period = _periods.at(i);
            uint256 periodIndex  = newTimestamp.div(period);
            _buckets[period].set(periodIndex , newPrice);
            if (_firstPeriodIndexes[period] == 0) {
                _firstPeriodIndexes[period] = periodIndex ;
                emit FirstIndex(period, periodIndex);
            }
            emit UpdatePrice(address(_priceFeeder), newPrice, newTimestamp, periodIndex);
        }
    }

    /**
     * @notice  Get time data series.
     * @param   period          Period of bucket.
     * @param   beginTimestamp  Begin timestamp of series.
     * @param   endTimestamp    End timestamp of series.
     * @return  Array of price for given time span.
     */
    function retrievePriceSeries(
        uint256 period,
        uint256 beginTimestamp,
        uint256 endTimestamp
    )
        external
        view
        returns (uint256[] memory)
    {
        require(beginTimestamp <= endTimestamp, "begin must be earlier than end");
        require(endTimestamp <= LibUtils.currentTime(), "end is in the future");
        require(_periods.contains(period), "period is not exist");

        uint256 beginIndex = beginTimestamp.div(period);
        require(beginIndex >= _firstPeriodIndexes[period], "begin is earlier than first time");
        uint256 endIndex = endTimestamp.div(period);

        uint256 lastNonZeroPrice = 0;
        uint256 seriesLength = endIndex.sub(beginIndex).add(1);
        // require(seriesLength > 0, "invalid length for series");
        uint256[] memory series = new uint256[](seriesLength);
        uint256 pos = 0;
        for (uint256 i = beginIndex; i <= endIndex; i++) {
            uint256 price = _buckets[period].get(i);
            // // price at index is 0, find previous non-zero price instead.
            if (price == 0) {
                // if lastNonZeroPrice is not initialized
                if (lastNonZeroPrice == 0) {
                    price = _buckets[period].findLastNonZeroValue(i);
                    require(price > 0, "missing first non-zero price");
                } else {
                    // or use lastNonZeroPrice as current price
                    price = lastNonZeroPrice;
                }
            }
            series[pos] = price;
            lastNonZeroPrice = price;
            pos++;
        }
        return series;
    }
}