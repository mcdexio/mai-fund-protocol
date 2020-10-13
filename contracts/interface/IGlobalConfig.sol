pragma solidity 0.6.10;

interface IGlobalConfig {

    function owner() external view returns (address);

    function isOwner() external view returns (bool);

    function renounceOwnership() external;

    function transferOwnership(address newOwner) external;

    function brokers(address broker) external view returns (bool);

    function pauseControllers(address broker) external view returns (bool);

    function withdrawControllers(address broker) external view returns (bool);

    function addBroker(address broker) external;

    function removeBroker(address broker) external;

    function isComponent(address component) external view returns (bool);

    function addComponent(address perpetual, address component) external;

    function removeComponent(address perpetual, address component) external;

    function addPauseController(address controller) external;

    function removePauseController(address controller) external;

    function addWithdrawController(address controller) external;

    function removeWithdrawControllers(address controller) external;
}