pragma solidity 0.6.10;

import "@openzeppelin/contracts/utils/Pausable.sol";

import "FundBase.sol";

contract FundManagement is FundBase, Pausable {

    modifier onlyManager() {
        require(msg.sender == _fundStorage.manager.account, "caller must be the manager");
        _;
    }

    modifier onlyAdministrator() {
        require(msg.sender == _fundAdministration.administrator(), "caller must be the administrator");
        _;
    }

    /**
     * @dev Pause the fund.
     */
    function pause() external override onlyAdministrator {
        _pause();
    }

    /**
     * @dev Unpause the fund.
     */
    function unpause() external override onlyAdministrator {
        _unpause();
    }

    function shutdownOnMaxDrawdownReached() external override {
        uint256 netAssetValue = _fundStorage.getNetAssetValue();
        uint256 maxNetAssetValue = _fundStorage.manager.maxNetAssetValue;
        require(maxNetAssetValue > netAssetValue, "no drawdown");
        require(
            maxNetAssetValue.sub(netAssetValue).wdiv(maxNetAssetValue) > _fundStorage.configuration.maxDrawdown,
            "max drawdown not reached"
        );
        _shutdown();
    }

    function shutdown() external override onlyAdministrator {
        _shutdown();
    }

    function _shutdown() internal {

    }

}