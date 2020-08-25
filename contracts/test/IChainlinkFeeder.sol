// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

// see https://github.com/smartcontractkit/chainlink/blob/v0.7.2/evm/contracts/interfaces/AggregatorInterface.sol
interface IChainlinkFeeder {
    function feeder() external view returns (address);
}
