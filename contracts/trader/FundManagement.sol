// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../interface/IDelegate.sol";

import "../lib/LibConstant.sol";
import "../lib/LibMathEx.sol";
import "../component/FundConfiguration.sol";
import "../component/FundProperty.sol";
import "../storage/FundStorage.sol";

interface IAdministration {
    function administrator() external view returns (address);
}

contract FundManagement is
    FundStorage,
    FundConfiguration,
    FundProperty
{

    using LibMathEx for uint256;

    event SetConfigurationEntry(bytes32 key, bytes32 value);
    event SetMaintainer(address indexed oldMaintainer, address indexed newMaintainer);
    event Shutdown(uint256 totalSupply);

    modifier onlyAdministrator() {
        require(msg.sender == administrator(), "caller must be the administrator");
        _;
    }

    function administrator() public view virtual returns (address) {
        return IAdministration(_creator).administrator();
    }

    /**
     * @dev Set value of configuration entry.
     * @param key   Name string of entry to set.
     * @param value Value of entry to set.
     */
    function setConfigurationEntry(bytes32 key, bytes32 value) external onlyAdministrator {
        if (key == "redeemingLockdownPeriod") {
            setRedeemingLockPeriod(uint256(value));
        } else if (key == "drawdownHighWaterMark") {
            setDrawdownHighWaterMark(uint256(value));
        } else if (key == "leverageHighWaterMark") {
            setLeverageHighWaterMark(uint256(value));
        } else if (key == "entranceFeeRate") {
            setEntranceFeeRate(uint256(value));
        } else if (key == "streamingFeeRate") {
            setStreamingFeeRate(uint256(value));
        } else if (key == "performanceFeeRate") {
            setPerformanceFeeRate(uint256(value));
        } else {
            revert("unrecognized key");
        }
        emit SetConfigurationEntry(key, value);
    }

    function setManager(address manager) external onlyAdministrator {
        require(manager != _manager, "same maintainer");
        emit SetMaintainer(_manager, manager);
        _manager = manager;
    }


    function setDelegator(address delegate) external onlyAdministrator {
        IDelegate(delegate).setDelegator(address(_perpetual), _manager);
    }

    function unsetDelegator(address delegate) external onlyAdministrator {
        IDelegate(delegate).unsetDelegator(address(_perpetual));
    }

    /**
     * @dev Pause the fund.
     */
    function pause() external {
        require(
            msg.sender == administrator() || msg.sender == _manager,
            "call must be administrator or maintainer"
        );
        _pause();
    }

    /**
     * @dev Unpause the fund.
     */
    function unpause() external onlyAdministrator {
        _unpause();
    }

    /**
     * @notice  Test can shutdown or not.
     * @dev     1. This is NOT view because method in perpetual.
     *          2. shutdown conditions:
     *              - leveraga reaches limit;
     *              - max drawdown reaches limit.
     * @return True if any condition is met.
     */
    function canShutdown()
        public
        returns (bool)
    {
        uint256 maxDrawdown = getDrawdown();
        if (maxDrawdown >= _drawdownHighWaterMark) {
            return true;
        }
        uint256 leverage = getLeverage().abs().toUint256();
        if (leverage >= _leverageHighWaterMark) {
            return true;
        }
        return false;
    }

    /**
     * @notice  Call by admin, or by anyone when shutdown conditions are met.
     * @dev     No way back.
     */
    function shutdown()
        external
        whenNotStopped
    {
        require(msg.sender == administrator() || canShutdown(), "caller is not administrator or cannot shutdown");

        address fundAccount = self();
        // claim fee until shutting down
        (uint256 netAssetValuePerShare, uint256 fee) = getNetAssetValuePerShareAndFee();
        // if shut down by admin, nav per share can still be high than max.
        // TODO: no longer need to update nav per share.
        updateFeeState(fee, netAssetValuePerShare);
        // set fund it self in redeeming mode.
        _balances[fundAccount] = _totalSupply;
        _redeemingBalances[fundAccount] = _totalSupply;
        _redeemingSlippage[fundAccount] = _shuttingDownSlippage;
        // enter shutting down mode.
        _stop();

        emit Shutdown(_totalSupply);
    }
}