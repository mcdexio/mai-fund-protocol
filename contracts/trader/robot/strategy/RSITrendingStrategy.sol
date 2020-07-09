// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "./RSIReader.sol";

contract RSITrendingStrategy is RSIReader {

    int256 public constant TARGET_LOWERBOUND = 10 ** 18 * -10;
    int256 public constant TARGET_UPPERBOUND = 10 ** 18 * 10;

    uint256[] internal _thresholds;
    int256[] internal _targets;

    constructor(
        uint256 period,
        uint256 numPeriod,
        uint256[] memory thresholds,
        int256[] memory targets
    )
        public
        RSIReader(period, numPeriod)
    {
        require(thresholds.length > 0, "threshold cannot be empty");
        require(thresholds.length == targets.length, "thresholds does not match with targets");
        for (uint256 i = 0; i < thresholds.length; i++) {
            require(thresholds[i] <= RSI_UPPERBOUND, "threshold is out of range");
            require(targets[i] >= TARGET_LOWERBOUND && targets[i] <= TARGET_UPPERBOUND, "target is out of range");
            require(i == 0 || thresholds[i] > thresholds[i - 1], "threshold must be monotune increasing");
        }
        _thresholds = thresholds;
        _targets = targets;
    }

    function getNextTarget() public view returns (int256) {
        uint256 rsi = getCurrentRSI();
        for (uint256 i = 0; i < _thresholds.length; i++) {
            if (rsi <= _thresholds[i]) {
                return _targets[i];
            }
        }
        return _targets[_thresholds.length - 1];
    }
}