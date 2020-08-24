// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "../interface/IDelegate.sol";
import "../lib/LibConstant.sol";
import "../lib/LibMathEx.sol";
import "../component/Collateral.sol";
import "../component/Configuration.sol";
import "../component/Property.sol";

contract FundManagement {
    using SafeERC20 for IERC20;
    using LibMathEx for uint256;

    event SetManager(address indexed oldMaintainer, address indexed newMaintainer);
    event Shutdown(uint256 totalSupply);

    /**
     * @notice  Set manager of fund.
     * @param   manager Address of manager.
     */
    function setManager(address manager)
        external
        onlyAdministrator
    {
        require(manager != _manager, "same maintainer");
        emit SetManager(_manager, manager);
        _manager = manager;
    }

    /**
     * @notice  Set manager as delegator of fund.
     *          A delegator is able to perform trading on fund margin account.
     * @param   delegate    Address of delegator.
     */
    function setDelegator(address delegate)
        external
        onlyAdministrator
    {
        IDelegate(delegate).setDelegator(address(_perpetual), _manager);
    }

    /**
     * @notice  Cancel manager as delegator of fund.
     * @param   delegate    Address of delegator.
     */
    function unsetDelegator(address delegate)
        external
        onlyAdministrator
    {
        IDelegate(delegate).unsetDelegator(address(_perpetual));
    }

    function approvePerpetual(uint256 amount)
        external
        onlyAdministrator
    {
        // IERC20(_collateral).safeApprove(address(_perpetual), amount);
        _approvePerpetual(amount);
    }

    /**
     * @dev Pause the fund.
     */
    function pause()
        external
        whenNotStopped
    {
        require(
            msg.sender == administrator() || msg.sender == _manager,
            "caller must be administrator or maintainer"
        );
        _pause();
    }

    /**
     * @dev Unpause the fund.
     */
    function unpause()
        external
        onlyAdministrator
    {
        _unpause();
    }
}