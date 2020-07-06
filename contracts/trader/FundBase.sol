// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../storage/FundStorage.sol";
import "../implement/FundAccount.sol";
import "../implement/FundCollateral.sol";
import "../implement/FundConfiguration.sol";
import "../implement/FundERC20Wrapper.sol";
import "../implement/FundFee.sol";
import "../implement/FundManagement.sol";
import "../implement/FundProperty.sol";

contract FundBase is
    FundStorage,
    FundAccount,
    FundCollateral,
    FundConfiguration,
    FundERC20Wrapper,
    FundFee,
    FundManagement,
    FundProperty
{
}