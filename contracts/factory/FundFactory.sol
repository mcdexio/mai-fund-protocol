pragma solidity 0.6.10;

import "../storage/UpgradableProxy.sol";

/**
 * @title Administration module for fund.
 */
contract FundAdministration {

    IGlobalConfig private _globalConfig;
    address[] _allFunds;
    mapping(address => bool) public _funds;

    event CreateSocialTradingFund(address indexed newFund);
    event CreateAutoTradingFund(address indexed newFund);
    event ShutdownFund(address indexed fund);

    constructor(address globalConfig) public {
        _globalConfig = IGlobalConfig(globalConfig);
    }

    modifier onlyAdministrator() {
        require(msg.sender == _globalConfig.owner(), "unauthorized caller");
        _;
    }

    /**
     * @dev Get address of global config.
     * @returns Address of account owning GlobalConfig contract.
     */
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
     * @param maintainer            Address of maintainer.
     * @param initialConfiguration  Array of configurations.
     * @return Address of new fund.
     */
    function createSocialTradingFund(
        string calldata name,
        string calldata symbol,
        address maintainer,
        address perpetual,
        address collateralDecimals,
        uint256[] calldata configuration
    )
        external
        onlyAdministrator
    {
        UpgradableProxy fundProxy = new UpgradableProxy();
        fundProxy.initialize(
            name,
            symbol,
            maintainer,
            perpetual,
            collateralDecimals,
            configuration
        );
        FundTrader trader = new SocialTrader(maintainer);
        fundProxy.upgradeTo("", trader.address);

        _funds[fundProxy.address] = true;
        _allFunds.push(fundProxy.address);

        emit CreateSocialTradingFund(fundProxy.address);
        return fundProxy.address;
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