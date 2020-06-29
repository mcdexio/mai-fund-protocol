pragma solidity 0.6.10;

/**
 * @title Administration module for fund.
 */
contract FundAdministration {

    IGlobalConfig private _globalConfig;
    mapping(address => bool) public funds;

    event CreateSocialTradingFund(address indexed perpetual, address indexed manager, uint256[] configuration);
    event CreateAutoTradingFund(address indexed perpetual, address indexed strategy, uint256[] configuration);
    event ShutdownFund(address indexed fundInstance);

    constructor(address globalConfig) public {
        _globalConfig = IGlobalConfig(globalConfig);
    }

    modifier onlyAdministrator() {
        require(msg.sender == _globalConfig.owner(), "unauthorized caller");
        _;
    }

    function globalConfig() public view returns (address) {
        return _globalConfig.address;
    }

    /**
     * @dev Use owner of global config as administrator.
     * @returns Address of account owning GlobalConfig contract.
     */
    function administrator() public view returns (address) {
        return _globalConfig.owner()
    }

    /**
     * @dev Create a fund maintained by social trader.
     * @param pereptual             Address of perpetual.
     * @param manager               Address of maintainer.
     * @param initialConfiguration  Array of configurations.
     * @return Address of new fund.
     */
    function createSocialTradingFund(
        address perpetual,
        address manager,
        uint256[] initialConfiguration
    )
        external onlyAdministrator
        returns (address)
    {
        IFund newFund = new SocialTrader(perpetual, manager, initialConfiguration);
        funds[newFund] = true;

        emit CreateSocialTradingFund(perpetual, manager, initialConfiguration);
        return newFund.address;
    }

    /**
     * @dev Create a fund maintained by strategy contract.
     *      Rebalance can be triggered by anyone once the condition defined by stratege satisfied.
     * @param pereptual             Address of perpetual.
     * @param manager               Address of maintainer.
     * @param initialConfiguration  Array of configurations.
     * @return Address of new fund.
     */
    function createAutoTradingFund(
        address perpetual,
        address strategy,
        uint256[] initialConfiguration
    )
        external onlyAdministrator
    {
        IFund newFund = new AutoTrader(perpetual, strategy, initialConfiguration);
        funds[newFund] = true;

        emit CreateAutoTradingFund(perpetual, strategy, initialConfiguration);
        return newFund.address;
    }

    /**
     * @dev Shutdown a running fund.
     */
    function shutdownFund(address fundInstance) external onlyAdministrator {
        require(funds[fundInstance], "fund not exist");
        funds[fundInstance] = false;

        // TODO: call method to turn fund into emergency shutdown state.
        emit ShutdownFund(fundInstance)
    }
}