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
 * @title   Collateral
 * @notice  Handle underlaying collaterals.
 */
contract Collateral is Initializable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address private _collateral;
    uint256 private _scaler;

    /**
     * @notice  Initialize collateral and decimals.
     * @param   decimals    Decimals of collateral token, will be verified with a staticcall.
     */
    function __Collateral_init_unchained(address collateral, uint8 decimals)
        internal
        initializer
    {
        require(decimals <= LibConstant.MAX_COLLATERAL_DECIMALS, "given decimals out of range");
        if (collateral == address(0)) {
            // ether
            require(decimals == 18, "ether must have decimals of 18");
        } else {
            // erc20 token
            (uint8 retrievedDecimals, bool ok) = _retrieveDecimals(collateral);
            require(!ok || (ok && retrievedDecimals == decimals), "decimals not match");
        }
        _collateral = collateral;
        _scaler = uint256(10**(LibConstant.MAX_COLLATERAL_DECIMALS.sub(decimals)));
    }

    function collateral() external view returns (address) {
        return _collateral;
    }

    function scaler() external view returns (uint256) {
        return _scaler;
    }

    /**
     * @notice  Read decimal from erc20 contract.
     * @param   token Address of erc20 token to read from.
     * @return  Decimals of token and wether the erc20 contract supports decimals() interface.
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

    // ** All interface call from upper layer use the decimals of the token, called 'rawAmount'.

    /**
     * @dev Indicates that whether current token is an erc20 token.
     * @return True if current token is an erc20 token.
     */
    function _isCollateralERC20()
        internal
        view
        returns (bool)
    {
        return _collateral != address(0);
    }

    /**
     * @dev Transfer token from user if token is erc20 token.
     *
     * @param trader Address of account owner.
     * @param amount Amount of token to be transferred into contract.
     * @return Internal representation of the raw amount.
     */
    function _pullFromUser(address trader, uint256 amount)
        internal
        returns (uint256)
    {
        require(amount > 0, "amount should not be 0");
        uint256 rawAmount = _toRawAmount(amount);
        if (_isCollateralERC20()) {
            IERC20(_collateral).safeTransferFrom(trader, address(this), rawAmount);
        } else {
            require(msg.value == rawAmount, "amount not match with sent value");
        }
        return rawAmount;
    }

    /**
     * @dev Transfer token to user no matter erc20 token or ether.
     *
     * @param trader    Address of account owner.
     * @param amount    Amount of token to be transferred to user.
     * @return Internal representation of the raw amount.
     */
    function _pushToUser(address payable trader, uint256 amount)
        internal
        returns (uint256)
    {
        require(amount > 0, "amount should not be 0");
        uint256 rawAmount = _toRawAmount(amount);
        if (_isCollateralERC20()) {
            IERC20(_collateral).safeTransfer(trader, rawAmount);
        } else {
            Address.sendValue(trader, rawAmount);
            // trader.transfer(amount);
        }
        return rawAmount;
    }

    /**
     * @dev Convert the represention of amount from raw to internal.
     *
     * @param rawAmount Amount with decimals of token.
     * @return Amount with internal decimals.
     */
    function _toInternalAmount(uint256 rawAmount) internal view returns (uint256) {
        return rawAmount.mul(_scaler);
    }

    /**
     * @dev Convert the represention of amount from internal to raw.
     *
     * @param amount Amount with internal decimals.
     * @return Amount with decimals of token.
     */
    function _toRawAmount(uint256 amount) internal view returns (uint256) {
        return amount.div(_scaler);
    }
}
