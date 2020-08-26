// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

import "../fund/Core.sol";
import "../fund/Getter.sol";

interface IDelegatable {
    function setDelegator(address perpetual, address newDelegator) external;
    function isDelegator(address trader, address perpetual, address target) external view returns (bool);
}

contract TestCore is
    Initializable,
    Core,
    Getter
{
    function initialize(
        string calldata name,
        string calldata symbol,
        uint8 collateralDecimals,
        address perpetual,
        uint256 cap
    )
        external
        initializer
    {
        __Core_init(name, symbol, collateralDecimals, perpetual, cap);
    }

    function setDelegator(address exchangeAddress, address delegator)
        external
    {
        IDelegatable(exchangeAddress).setDelegator(address(_perpetual), delegator);
    }
}