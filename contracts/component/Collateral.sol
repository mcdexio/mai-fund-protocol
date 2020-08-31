// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../lib/LibConstant.sol";

interface ITokenWithDecimals {
    function decimals() external view returns (uint8);
}

/**
 * @title   Collateral Module
 * @dev     Handle underlaying collaterals.
 *          In this file, parameter named with:
 *              - [amount] means internal amount
 *              - [rawAmount] means amount in decimals of underlaying collateral
 *
 */
contract Collateral is Initializable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 internal _collateralToken;
    uint256 internal _scaler;

    /**
     * @dev     Initialize collateral and decimals.
     * @param   decimals    Decimals of collateral token, will be verified with a staticcall.
     */
    function __Collateral_init_unchained(address collateral, uint8 decimals)
        internal
        initializer
    {
        require(decimals <= LibConstant.MAX_COLLATERAL_DECIMALS, "decimals out of range");
        if (collateral == address(0)) {
            // ether
            require(decimals == 18, "ether requires decimals 18");
        } else {
            // erc20 token
            (uint8 retrievedDecimals, bool ok) = _retrieveDecimals(collateral);
            require(!ok || (ok && retrievedDecimals == decimals), "unmatched decimals");
        }
        _collateralToken = IERC20(collateral);
        _scaler = uint256(10**(LibConstant.MAX_COLLATERAL_DECIMALS.sub(decimals)));
    }

    /**
     * @dev     Read decimal from erc20 contract.
     * @param   token Address of erc20 token to read from.
     * @return  Decimals of token and if the erc20 contract supports decimals() interface.
     */
    function _retrieveDecimals(address token)
        internal
        view
        returns (uint8, bool)
    {
        (bool success, bytes memory result) = token.staticcall(abi.encodeWithSignature("decimals()"));
        if (success && result.length >= 32) {
            return (abi.decode(result, (uint8)), success);
        }
        return (0, false);
    }

    /**
     * @dev     Approve collateral to spender. Used for depositing erc20 to perpetual.
     * @param   spender     Address of spender.
     * @param   rawAmount   Amount to approve.
     */
    function _approvalTo(address spender, uint256 rawAmount)
        internal
    {
        require(!_isCollateralERC20(), "no need to approve");
        _collateralToken.safeApprove(spender, rawAmount);
    }


    /**
     * @dev Indicates that whether current token is an erc20 token.
     * @return True if current token is an erc20 token.
     */
    function _isCollateralERC20()
        internal
        view
        returns (bool)
    {
        return address(_collateralToken) != address(0);
    }

    /**
     * @dev     Transfer token from user if token is erc20 token.
     * @param   trader  Address of account owner.
     * @param   amount  Amount of token to be transferred into contract.
     * @return Internal representation of the raw amount.
     */
    function _pullFromUser(address trader, uint256 amount)
        internal
        returns (uint256)
    {
        require(amount > 0, "zero amount");
        uint256 rawAmount = _toRawAmount(amount);
        if (_isCollateralERC20()) {
            _collateralToken.safeTransferFrom(trader, address(this), rawAmount);
        } else {
            require(msg.value == rawAmount, "unmatched sent value");
        }
        return rawAmount;
    }

    /**
     * @dev Transfer token to user no matter erc20 token or ether.
     * @param trader    Address of account owner.
     * @param amount    Amount of token to be transferred to user.
     * @return Internal representation of the raw amount.
     */
    function _pushToUser(address payable trader, uint256 amount)
        internal
        returns (uint256)
    {
        require(amount > 0, "zero amount");
        uint256 rawAmount = _toRawAmount(amount);
        if (_isCollateralERC20()) {
            _collateralToken.safeTransfer(trader, rawAmount);
        } else {
            Address.sendValue(trader, rawAmount);
            // trader.transfer(amount);
        }
        return rawAmount;
    }

    /**
     * @dev Convert the represention of amount from raw to internal.
     * @param rawAmount Amount with decimals of token.
     * @return Amount with internal decimals.
     */
    function _toInternalAmount(uint256 rawAmount) internal view returns (uint256) {
        return rawAmount.mul(_scaler);
    }

    /**
     * @dev Convert the represention of amount from internal to raw.
     * @param amount Amount with internal decimals.
     * @return Amount with decimals of token.
     */
    function _toRawAmount(uint256 amount) internal view returns (uint256) {
        return amount.div(_scaler);
    }

    uint256[18] private __gap;
}
