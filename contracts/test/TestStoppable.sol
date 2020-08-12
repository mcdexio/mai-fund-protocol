// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../storage/Stoppable.sol";

contract TestStoppable is Stoppable {

    function stop() external {
        _stop();
    }

    function callableWhenNotStopped() external view whenNotStopped returns (bool) {
        return true;
    }

    function callableWhenStopped() external view whenStopped returns (bool) {
        return true;
    }
}