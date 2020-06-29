pragma solidity 0.6.10;

interface ITradingStrategy {
    function getNextResult(address fund) external returns (int256);
}