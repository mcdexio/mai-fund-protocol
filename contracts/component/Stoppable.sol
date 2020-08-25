// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";

contract StoppableUpgradeSafe is Initializable, ContextUpgradeSafe {

    event Stopped(address indexed caller);

    bool internal _stopped;

    function __Stoppable_init() internal initializer {
        __Context_init_unchained();
        __Stoppable_init_unchained();
    }

    function __Stoppable_init_unchained() internal initializer {
        _stopped = false;
    }

    /**
     * @dev Returns true if the contract is stoped.
     */
    function stopped() public view returns (bool) {
        return _stopped;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not stopped.
     *
     * Requirements:
     *
     * - The contract must not be stopped.
     */
    modifier whenNotStopped() {
        require(!_stopped, "Stoppable: stopped");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is stopped.
     *
     * Requirements:
     *
     * - The contract must be stopped.
     */
    modifier whenStopped() {
        require(_stopped, "Stoppable: not stopped");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be stopped.
     */
    function _stop() internal virtual whenNotStopped {
        _stopped = true;
        emit Stopped(msg.sender);
    }

    uint256[19] private __gap;
}