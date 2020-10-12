// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../lib/LibMathEx.sol";

contract TestLibMathEx {
    function wmulU(uint256 x, uint256 y) public pure returns (uint256 z) {
        return LibMathEx.wmul(x, y);
    }

    function wdivU(uint256 x, uint256 y) public pure returns (uint256 z) {
        return LibMathEx.wdiv(x, y);
    }

    function wfracU(uint256 x, uint256 y, uint256 z) public pure returns (uint256 r) {
        return LibMathEx.wfrac(x, y, z);
    }

    function wmulS(int256 x, int256 y) public pure returns (int256 z) {
        return LibMathEx.wmul(x, y);
    }

    function wdivS(int256 x, int256 y) public pure returns (int256 z) {
        return LibMathEx.wdiv(x, y);
    }

    function wfracS(int256 x, int256 y, int256 z) public pure returns (int256 r) {
        return LibMathEx.wfrac(x, y, z);
    }

    function absS(int256 x) public pure returns (int256) {
        return LibMathEx.abs(x);
    }

    function negS(int256 a) public pure returns (int256) {
        return LibMathEx.neg(a);
    }

    function roundHalfUpS(int256 x, int256 y) public pure returns (int256) {
        return LibMathEx.roundHalfUp(x, y);
    }
}
