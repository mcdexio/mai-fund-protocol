// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";

contract Context is ContextUpgradeSafe {
    /**
     * @notice  Return address of fund contract.
     */
    function _self()
        internal
        view
        virtual
        returns (address)
    {
        return address(this);
    }

    function _now() internal view returns (uint256) {
        return block.timestamp;
    }

    uint256[20] private __gap;
}
