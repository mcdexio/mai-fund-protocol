// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "./Storage.sol";
import "./Proxy.sol";

contract UpgradableProxy is Proxy, Storage {
    string private _version;

    event Upgraded(string version, address indexed implementation);

    function version() external view returns (string memory) {
        return _version;
    }

    function upgradeTo(string memory newVersion, address newImplementation) public {
        require(_implementation() != newImplementation, "implementation unchange");
        _version = newVersion;
        setImplementation(newImplementation);
        emit Upgraded(newVersion, newImplementation);
    }
}
