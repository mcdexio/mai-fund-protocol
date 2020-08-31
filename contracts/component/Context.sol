// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";

/**
 * @title A contect object contains.
 */
contract Context is ContextUpgradeSafe {
    /**
     * @dev Return address of fund contract.
     */
    function _self()
        internal
        view
        virtual
        returns (address)
    {
        return address(this);
    }

    /**
     * @dev Return current timestamp on chain.
     */
    function _now()
        internal
        view
        virtual
        returns (uint256)
    {
        return block.timestamp;
    }

    uint256[20] private __gap;
}
