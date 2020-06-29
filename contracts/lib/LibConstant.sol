pragma solidity 0.6.10;

library LibConstant {
    int256 private constant SIGNED_ONE = 10 ** 18;
    uint256 private constant UNSIGNED_ONE = 10 ** 18;
    uint256 private constant MAX_DECIMALS = 18;
    uint256 private constant SECONDS_PER_YEAR = 365 * 86400;
}