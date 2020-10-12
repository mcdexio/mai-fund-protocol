// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";

import "../lib/LibEnumerableMap.sol";

interface IPriceFeeder {
    function price() external view returns (uint256 lastPrice, uint256 lastTimestamp);
}

contract PeriodicPriceBucket is OwnableUpgradeSafe {

    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using LibEnumerableMap for LibEnumerableMap.AppendOnlyUintToUintMap;

    uint256 public constant MAX_BUCKETS = 32;

    IPriceFeeder internal _priceFeeder;
    // period => period index => price
    EnumerableSet.UintSet internal _periods;
    mapping(uint256 => uint256) internal _firstPeriodIndexes;
    mapping(uint256 => LibEnumerableMap.AppendOnlyUintToUintMap) internal _buckets;

    event FirstIndex(uint256 period, uint256 periodIndex);
    event UpdatePrice(address indexed feeder, uint256 price, uint256 timestamp, uint256 priceIndex);
    event AddBucket(uint256 period);
    event RemoveBucket(uint256 period);
    event UpdatePriceFeeder(address indexed previousPriceFeeder, address indexed newPriceFeeder);

    function initialize(address priceFeeder)
        external
        initializer
    {
        __Ownable_init();
        __PeriodicPriceBucket_init_unchained(priceFeeder);
    }

    function __PeriodicPriceBucket_init_unchained(address priceFeeder)
        internal
        initializer
    {
        _setPriceFeeder(priceFeeder);
    }

    /**
     * @notice  Return all available periods as an array.
     * @dev     According to the implementation of EnumerableSet,
     *          order of data may change after removal.
     * @return  Array of all available periods.
     */
    function buckets()
        external
        view
        returns (uint256[] memory)
    {
        uint256 bucketCount = _periods.length();
        uint256[] memory bucketList = new uint256[](bucketCount);
        for (uint256 i = 0; i < _periods.length(); i++) {
            bucketList[i] = _periods.at(i);
        }
        return bucketList;
    }

    /**
     * @notice  Test if a period exists.
     * @return  Return true if a bucket already exists.
     */
    function hasBucket(uint256 period)
        external
        view
        returns (bool)
    {
        return _periods.contains(period);
    }

    /**
     * @notice  Add time bucket, no duplication. period must be within (0, 86400*7]
     * @param   period  Period of bucket to be added.
     */
    function addBucket(uint256 period)
        external
        onlyOwner
    {
        require(period <= 86400*7, "period must be less than 1 week");
        require(period > 0, "period must be greater than 0");
        require(_periods.length() < MAX_BUCKETS, "number of buckets has already reached the limit");
        bool success = _periods.add(period);
        require(success, "period is duplicated");
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
        require(_periods.remove(period), "period does not exist");
        delete _buckets[period];
        delete _firstPeriodIndexes[period];
        emit RemoveBucket(period);
    }

    function setPriceFeeder(address newPriceFeeder)
        external
        onlyOwner
    {
        require(Address.isContract(newPriceFeeder), "price feeder must be contract");
        _setPriceFeeder(newPriceFeeder);
    }

    /**
     * @notice  Read price from oracle, update all buckets.
     *          The latest price in a bucket will overwrite price in the same segment.
     */
    function updatePrice()
        external
    {
        (
            uint256 newPrice,
            uint256 newTimestamp
        ) =  _priceFeeder.price();
        require(newPrice > 0, "invalid price");
        require(newTimestamp > 0, "invalid timestamp");
        uint256 numPeriods = _periods.length();
        for (uint256 i = 0; i < numPeriods; i++) {
            uint256 period = _periods.at(i);
            uint256 periodIndex  = newTimestamp.div(period);
            _buckets[period].set(periodIndex , newPrice);
            if (_firstPeriodIndexes[period] == 0) {
                // here, when the periodIndex == 0
                // the _firstPeriodIndexes will be overwritten.
                // but this is not possible in production environment
                // so let's ignore it.
                _firstPeriodIndexes[period] = periodIndex;
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
        require(beginTimestamp <= endTimestamp, "begin must be earlier than or equal to end");
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

    function _setPriceFeeder(address newPriceFeeder)
        internal
    {
        require(newPriceFeeder != address(0), "invalid price feeder address");
        require(newPriceFeeder != address(_priceFeeder), "price feeder duplicated");
        emit UpdatePriceFeeder(address(_priceFeeder), newPriceFeeder);
        _priceFeeder = IPriceFeeder(newPriceFeeder);
    }
}