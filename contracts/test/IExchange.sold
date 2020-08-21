// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

struct OrderSignature {
    bytes32 config;
    bytes32 r;
    bytes32 s;
}

struct OrderParam {
    address trader;
    uint256 amount;
    uint256 price;
    bytes32 data;
    OrderSignature signature;
}

interface IExchange {

    function matchOrders(
        OrderParam memory takerOrderParam,
        OrderParam[] memory makerOrderParams,
        address _perpetual,
        uint256[] memory amounts
    ) external;

    function matchOrderWithAMM(
        OrderParam memory takerOrderParam,
        address _perpetual,
        uint256 amount
    ) external;
}
