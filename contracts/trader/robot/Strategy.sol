// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../../external/LibTypes.sol";
import "../../lib/LibUtils.sol";
import "../../lib/LibMathEx.sol";
import "../../storage/FundStorage.sol";
import "../FundBase.sol";

interface ITradingStrategy {
    function getNextTarget() external view returns (int256);
}