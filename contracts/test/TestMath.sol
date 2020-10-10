// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../lib/LibMathEx.sol";

contract TestMath {

    using LibMathEx for int256;

    function abs(int256 x) public pure returns (int256 y) {
        y = x.abs();
    }

    function neg(int256 x) public pure returns (int256 y) {
        y = x.neg();
    }
}