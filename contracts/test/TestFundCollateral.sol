// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../component/FundCollateral.sol";

contract TestFundCollateral is FundCollateral {

    receive() external payable {
        require(_collateral == address(0), "this contract does not accept ether");
        require(msg.sender == address(_perpetual), "only receive ethers from perpetual");
    }


    constructor(address perpetual)
        public
    {
        _perpetual = IPerpetual(perpetual);
    }

    function initialize(address collateral, uint8 decimal)
        external
    {
        _initialize(collateral, decimal);
    }

    function retrieveDecimals(address token)
        external
        view
        returns (uint8, bool)
    {
        return _retrieveDecimals(token);
    }

    function isToken()
        external
        view
        returns (bool)
    {
        return _isToken();
    }

    function approvePerpetual(uint256 amount)
        external
    {
        _approvePerpetual(amount);
    }

    function pullCollateralFromUser(address trader, uint256 amount)
        external
        payable
        returns (uint256)
    {
        return _pullCollateralFromUser(trader, amount);
    }

    function pushCollateralToUser(address payable trader, uint256 amount)
        external
        returns (uint256)
    {
        return _pushCollateralToUser(trader, amount);
    }

    function pullCollateralFromPerpetual(uint256 amount)
        external
    {
        return _pullCollateralFromPerpetual(amount);
    }

    function pushCollateralToPerpetual(uint256 amount)
        external
        payable
    {
        _pushCollateralToPerpetual(amount);
    }

    function toInternalAmount(uint256 rawAmount)
        external
        view
        returns (uint256)
    {
        return _toInternalAmount(rawAmount);
    }

    function toRawAmount(uint256 amount)
        external
        view
        returns (uint256)
    {
        return _toRawAmount(amount);
    }
}