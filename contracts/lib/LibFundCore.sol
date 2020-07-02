// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../interface/IPerpetual.sol";

import "./LibCollateral.sol";
import "./LibFundAccount.sol";
import "./LibFundConfiguration.sol";
import "./LibFundFee.sol";

library LibFundCore {

    using LibCollateral for LibCollateral.Collateral;
    using LibFundConfiguration for LibFundConfiguration.Configuration;

    struct Core {
        // ERC20 name
        string name;
        // ERC20 symbol
        string symbol;
        // underlaying perpetual.
        IPerpetual perpetual;
        // core data of fund
        uint256 shareTotalSupply;
        address maintainer;
        LibCollateral.Collateral collateral;
        LibFundFee.FeeState feeState;
        LibFundConfiguration.Configuration configuration;
        mapping(address => LibFundAccount.Account) accounts;
        // initialize guard
        bool isInitialized;
    }

    function initialize(
        Core storage core,
        string memory name,
        string memory symbol,
        address maintainer,
        address perpetual,
        uint8 collateralDecimals,
        uint256[] memory configuration
    )
        external
    {
        require(!core.isInitialized, "storage is already initialzed");
        require(maintainer != address(0), "fund must have a maintainer");
        require(perpetual != address(0), "fund must associate with a perpetual");

        core.name = name;
        core.symbol = symbol;
        core.maintainer = maintainer;
        core.perpetual = IPerpetual(perpetual);
        // initialize collateral
        address collateral = core.perpetual.collateral();
        core.collateral.initialize(collateral, collateralDecimals);
        // configuration
        core.configuration.initialize(configuration);
        core.isInitialized = true;
    }
}