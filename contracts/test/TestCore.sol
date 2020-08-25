// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

import "../fund/Core.sol";
import "../fund/Getter.sol";

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

}