// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../lib/LibCollateral.sol";
import "../lib/LibFundAccount.sol";
import "../lib/LibFundConfiguration.sol";
import "../lib/LibFundCore.sol";
import "../lib/LibFundFee.sol";

contract Storage {
    using LibFundCore for LibFundCore.Core;

    LibFundCore.Core internal _core;

    constructor() internal {}

    /**
     * @notice Initialize core data.
     */
    function initialize(
        string calldata name,
        string calldata symbol,
        address maintainer,
        address perpetual,
        uint8 collateralDecimals,
        uint256[] calldata configuration
    )
        external
    {
        _core.initialize(
            name,
            symbol,
            maintainer,
            perpetual,
            collateralDecimals,
            configuration
        );
    }
}