// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "./LibConstant.sol";

library LibMathEx {

    using SafeMath for uint256;
    using SignedSafeMath for int256;

    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(y).add(LibConstant.UNSIGNED_ONE / 2) / LibConstant.UNSIGNED_ONE;
    }

    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(LibConstant.UNSIGNED_ONE).add(y / 2) / y;
    }

    function wfrac(uint256 x, uint256 y, uint256 z) internal pure returns (uint256 r) {
        require(z != 0, "division by zero");
        r = x.mul(y).div(z);
    }

    function wmul(int256 x, int256 y) internal pure returns (int256 z) {
        z = x.mul(y).add(LibConstant.SIGNED_ONE / 2) / LibConstant.SIGNED_ONE;
    }

    function wdiv(int256 x, int256 y) internal pure returns (int256 z) {
        z = x.mul(LibConstant.SIGNED_ONE).add(y / 2) / y;
    }

    function wfrac(int256 x, int256 y, int256 z) internal pure returns (int256 r) {
        require(z != 0, "division by zero");
        r = x.mul(y).div(z);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     * see https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.0.1/contracts/math/SafeMath.sol#L146
     */
    function mod(uint256 x, uint256 m) internal pure returns (uint256) {
        require(m != 0, "mod by zero");
        return x % m;
    }

    function abs(int256 x) internal pure returns (int256) {
        return x >= 0? x: -x;
    }
}