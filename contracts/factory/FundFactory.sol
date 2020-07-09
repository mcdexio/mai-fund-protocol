// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "../external/openzeppelin-upgrades/contracts/upgradeability/InitializableAdminUpgradeabilityProxy.sol";
import "../interface/IGlobalConfig.sol";
// import "../interface/IDelegate.sol";

interface IDelegateSetter {
    function setDelegator(address) external;
    function unsetDelegator(address) external;
}


/**
 * @title Administration module for fund.
 */
contract FundFactory {

    using EnumerableSet for EnumerableSet.AddressSet;

    IGlobalConfig internal _globalConfig;
    address internal _implementation;
    EnumerableSet.AddressSet internal _proxies;

    event Register(address indexed caller, address indexed proxy, address indexed implementation);
    event Deregister(address indexed caller, address indexed proxy);
    event UpgradeImplementation(address indexed newImplementation);

    constructor(address globalConfig) public {
        _globalConfig = IGlobalConfig(globalConfig);
    }

    modifier onlyAdministrator() {
        require(msg.sender == _globalConfig.owner(), "unauthorized caller");
        _;
    }

    /**
     * @dev Get address of global config.
     * @return Address of account owning GlobalConfig contract.
     */
    function globalConfig() public view returns (address) {
        return address(_globalConfig);
    }

    /**
     * @dev Use owner of global config as administrator.
     * @return Address of account owning GlobalConfig contract.
     */
    function administrator() public view returns (address) {
        return _globalConfig.owner();
    }

    function setImplementation(address newImplementation)
        external
        onlyAdministrator
    {
        require(_implementation != newImplementation, "implementation duplicated");
        _implementation = newImplementation;
        emit UpgradeImplementation(newImplementation);
    }

    function createFundProxy(bytes calldata initializeData)
        external
        onlyAdministrator
        returns (address)
    {
        address proxy = createProxy(_implementation, initializeData);
        register(proxy);
        return proxy;
    }

    function numProxies() external view returns (uint256) {
        return _proxies.length();
    }

    function getProxies(uint256 index) external view returns (address) {
        return _proxies.at(index);
    }

    function isRegistered(address proxy) external view returns (bool) {
        return _proxies.contains(proxy);
    }

    function createProxy(address implementation, bytes memory initializeData) internal returns (address) {
        InitializableAdminUpgradeabilityProxy proxy = new InitializableAdminUpgradeabilityProxy();
        proxy.initialize(implementation, address(this), initializeData);
        return address(proxy);
    }

    function register(address proxy) internal {
        _proxies.add(proxy);
        emit Register(msg.sender, proxy, _implementation);
    }

    function deregister(address proxy) internal {
        _proxies.remove(proxy);
        emit Deregister(msg.sender, proxy);
    }

}