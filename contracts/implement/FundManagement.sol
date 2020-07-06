// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "../storage/FundStorage.sol";

interface IOwnable {
    function owner() external view returns (address);
}

contract FundManagement is FundStorage, Pausable {

    IOwnable _administrator;

    modifier onlyAdministrator() {
        require(msg.sender == _administrator.owner(), "caller must be the administrator");
        _;
    }

    /**
     * @dev Pause the fund.
     */
    function pause() external onlyAdministrator {
        _pause();
    }

    /**
     * @dev Unpause the fund.
     */
    function unpause() external onlyAdministrator {
        _unpause();
    }

    function shutdownOnMaxDrawdownReached() external {
        // uint256 netAssetValue = _core.getNetAssetValue();
        // uint256 maxNetAssetValue = _core.manager.maxNetAssetValue;
        // require(maxNetAssetValue > netAssetValue, "no drawdown");
        // require(
        //     maxNetAssetValue.sub(netAssetValue).wdiv(maxNetAssetValue) > _core.configuration.maxDrawdown,
        //     "max drawdown not reached"
        // );
        _shutdown();
    }

    function shutdown() external onlyAdministrator {
        _shutdown();
    }

    function _shutdown() internal {

    }

}