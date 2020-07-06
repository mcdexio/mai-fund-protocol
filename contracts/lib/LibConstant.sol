// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

library LibConstant {
    int256 internal constant SIGNED_ONE = 10 ** 18;
    uint256 internal constant UNSIGNED_ONE = 10 ** 18;

    uint256 internal constant SHARE_TOKEN_DECIMALS = 18;
    uint256 internal constant MAX_COLLATERAL_DECIMALS = 18;

    uint256 internal constant SECONDS_PER_YEAR = 365 * 86400;
    uint256 internal constant RATE_UPPERBOUND = 10 ** 18 * 100;
}