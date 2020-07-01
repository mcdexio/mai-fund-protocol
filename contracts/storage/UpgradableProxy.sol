pragma solidity 0.6.10;

import "Storage.sol";
import "Proxy.sol";

contract UpgradableProxy is Proxy, Storage {

    event Upgraded(string version, address indexed implementation);

    function upgradeTo(string version, address implementation) public {
        require(_implementation != implementation);
        _version = version;
        setImplementation(implementation);
        Upgraded(version, implementation);
    }
}
