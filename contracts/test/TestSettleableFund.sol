// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

import "../fund/SettleableFund.sol";
import "../fund/Getter.sol";

interface IDelegatable {
    function setDelegator(address perpetual, address newDelegator) external;
    function isDelegator(address trader, address perpetual, address target) external view returns (bool);
}

contract TestSettleableFund is
    Initializable,
    SettleableFund,
    Getter
{
    function initialize(
        string calldata tokenName,
        string calldata tokenSymbol,
        uint8 collateralDecimals,
        address perpetualAddress,
        uint256 tokenCap
    )
        external
        initializer
    {
        __SettleableFund_init(tokenName, tokenSymbol, collateralDecimals, perpetualAddress, tokenCap);
    }

    function setDelegator(address exchangeAddress, address delegator)
        external
    {
        IDelegatable(exchangeAddress).setDelegator(address(_perpetual), delegator);
    }
}