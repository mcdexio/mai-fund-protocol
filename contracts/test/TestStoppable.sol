// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../component/Stoppable.sol";

contract TestStoppable is StoppableUpgradeSafe {

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