// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SignedSafeMath.sol";

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
        z = roundHalfUp(x.mul(y), LibConstant.SIGNED_ONE) / LibConstant.SIGNED_ONE;
    }

    function wdiv(int256 x, int256 y) internal pure returns (int256 z) {
        if (y < 0) {
            y = -y;
            x = -x;
        }
        z = roundHalfUp(x.mul(LibConstant.SIGNED_ONE), y) / y;
    }

    function wfrac(int256 x, int256 y, int256 z) internal pure returns (int256 r) {
        int256 t = x.mul(y);
        if (z < 0) {
            z = neg(z);
            t = neg(t);
        }
        r = roundHalfUp(t, z) / z;
    }

    function abs(int256 x) internal pure returns (int256) {
        return x >= 0 ? x: neg(x);
    }

    function neg(int256 a) internal pure returns (int256) {
        return SignedSafeMath.sub(int256(0), a);
    }

    // ROUND_HALF_UP rule helper. You have to call roundHalfUp(x, y) / y to finish the rounding operation
    // 0.5 ≈ 1, 0.4 ≈ 0, -0.5 ≈ -1, -0.4 ≈ 0
    function roundHalfUp(int256 x, int256 y) internal pure returns (int256) {
        require(y > 0, "roundHalfUp only supports y > 0");
        if (x >= 0) {
            return x.add(y / 2);
        }
        return x.sub(y / 2);
    }
}