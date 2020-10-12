// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SignedSafeMath.sol";

import "./RSIReader.sol";

contract RSITrendingStrategy is RSIReader {

    using SafeCast for int256;

    struct InputTargetEntry {
        uint128 begin;
        uint128 end;
        int128 target;
    }

    // upperbound && lowerbound, HARD limit is from [-10 ~ +10],
    // the range may be narrower in different implements.
    int256 public constant TARGET_LOWERBOUND = 10 ** 18 * -10;
    int256 public constant TARGET_UPPERBOUND = 10 ** 18 * 10;

    int256 internal _lastTarget;
    uint256 internal _lastSegment;
    uint256[] internal _seperators;
    mapping(uint256 => mapping(uint256 => int256)) internal _transfers;

    /**
     * @dev Target leverage calculator. A lookup table with input from rsi oralce, acctually.
     * @param period            Trading period in seconds.
     * @param numPeriod         Period required for calculation.
     * @param seperators        Rsi triggering segments, something like | 40 | 50 | 60 | (decimals = 18).
     *                          Values must be monotune increasing and all values could not excceed 100 (RSI max value).
     * @param transferEntries   Start / Stop segments and ouput, Transferring table.
     */
    constructor(
        address priceReader,
        uint256 period,
        uint256 numPeriod,
        uint256[] memory seperators,
        InputTargetEntry[] memory transferEntries
    )
        public
        RSIReader(priceReader, period, numPeriod)
    {
        // require(thresholds.length > 0, "threshold cannot be empty");
        // require(thresholds.length.add(1) == targets.length, "thresholds does not match with targets");
        // // ensure thresholds are in increasing order and no duplicated value
        // // ensure target between [-10 ~ +10]
        // for (uint256 i = 0; i < thresholds.length; i++) {
        //     require(thresholds[i] <= RSI_UPPERBOUND, "threshold is out of range");
        //     require(targets[i] >= TARGET_LOWERBOUND && targets[i] <= TARGET_UPPERBOUND, "target is out of range");
        //     require(i == 0 || thresholds[i] > thresholds[i - 1], "thresholds must be monotune increasing");
        // }
        // _seperators = thresholds;
        // _targets = targets;
        require(seperators.length > 0, "no seperators");
        for (uint256 i = 0; i < seperators.length; i++) {
            require(seperators[i] > RSI_LOWERBOUND && seperators[i] < RSI_UPPERBOUND, "seperators out of range");
            require(i == 0 || seperators[i] > seperators[i.sub(1)], "seperators must be monoture increasing");
        }
        uint256 maxSegment = seperators.length.add(1);
        for (uint256 i = 0; i < transferEntries.length; i++) {
            require(transferEntries[i].begin <= maxSegment, "begin out of range");
            require(transferEntries[i].end <= maxSegment, "end out of range");
            require(
                transferEntries[i].target <= TARGET_UPPERBOUND &&
                transferEntries[i].target >= TARGET_LOWERBOUND,
                "target leverage out of range"
            );
            _transfers[transferEntries[i].begin][transferEntries[i].end] = transferEntries[i].target;
        }
        _seperators = seperators;
        _lastSegment = maxSegment; // invalid value
    }

    function isValidSegment(uint256 segment) internal view returns (bool) {
        return segment <= _seperators.length;
    }

    /**
     * @dev get next leverage target according to rsi trends.
     * @return Ouput leverage target, between [-10 ~ +10].
     */
    function getNextTarget() public returns (int256) {
        uint256 rsi = getCurrentRSI();
        uint256 segment = _seperators.length;
        for (uint256 i = 0; i < _seperators.length; i++) {
            if (rsi < _seperators[i]) {
                segment = i;
                break;
            }
        }
        if (!isValidSegment(_lastSegment)) {
            _lastSegment = segment;
        }
        int256 target = _transfers[_lastSegment][segment];
        if (target != _lastTarget) {
            _lastSegment = segment;
            _lastTarget = target;
        }
        return target;
    }
}