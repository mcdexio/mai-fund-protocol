// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;


interface IDelegate {
    function setDelegator(address perpetual, address newDelegator) external;

    function unsetDelegator(address perpetual) external;

    function isDelegator(address trader, address perpetual, address target) external view returns (bool);
}