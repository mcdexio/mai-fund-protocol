// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

interface IGlobalConfig {
    function owner() external view returns (address);

    function brokers(address broker) external view returns (bool);

    function addBroker(address broker) external;

    function removeBroker() external;

    function addComponent(address perpetual, address component) external;

}
