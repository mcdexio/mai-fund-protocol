pragma solidity 0.6.10;

import "../lib/LibCollateral.sol";
import "../lib/LibFundAccount.sol";
import "../lib/LibFundConfiguration.sol";
import "../lib/LibFundCore.sol";
import "../lib/LibFundFees.sol";

contract Storage {
    using LibFundCore for LibFundCore.Core;

    LibFundCore.Core internal _core;

    /**
     * @notice Initialize core data.
     */
    function initialize(
        string calldata name,
        string calldata symbol,
        address maintainer,
        address perpetual,
        address collateralDecimals,
        uint256[] calldata configuration
    )
        external
    {
        _core.initialize(
            name,
            symbol,
            maintainer,
            collateralDecimals,
            configuration
        );
    }
}