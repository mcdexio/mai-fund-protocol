// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../lib/LibConstant.sol";

/**
 * @title   Collateral Module
 * @dev     Handle underlying collaterals.
 *          In this file, parameter named with:
 *              - [amount] means internal amount
 *              - [rawAmount] means amount in decimals of underlying collateral
 *
 */
contract Collateral is Initializable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 internal _collateralToken;
    uint256 internal _scaler;

    /**
     * @dev     Initialize collateral and decimals.
     * @param   collateralAddress   Address of collateral, 0x0 if using ether.
     * @param   decimals            Decimals of collateral token, will be verified with a staticcall.
     */
    function __Collateral_init_unchained(address collateralAddress, uint8 decimals)
        internal
        initializer
    {
        require(decimals <= LibConstant.MAX_COLLATERAL_DECIMALS, "bad decimals");
        if (collateralAddress == address(0)) {
            // ether
            require(decimals == 18, "decimals is not 18");
        } else {
            // erc20 token
            (uint8 retrievedDecimals, bool ok) = _retrieveDecimals(collateralAddress);
            require(!ok || (ok && retrievedDecimals == decimals), "bad decimals");
        }
        _collateralToken = IERC20(collateralAddress);
        _scaler = uint256(10**(LibConstant.MAX_COLLATERAL_DECIMALS.sub(uint256(decimals))));
    }

    /**
     * @notice  Try to retreive decimals from an erc20 contract.
     * @return  Decimals and true if success or 0 and false.
     */
    function _retrieveDecimals(address tokenAddress)
        internal
        view
        returns (uint8, bool)
    {
        (bool success, bytes memory result) = tokenAddress.staticcall(abi.encodeWithSignature("decimals()"));
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
        require(_isCollateralERC20(), "need no approve");
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
     * @dev     Get collateral balance in account.
     * @param   account     Address of account.
     * @return  Raw repesentation of collateral balance.
     */
    function _internalBalanceOf(address account)
        internal
        view
        returns (uint256)
    {
        return _toInternalAmount(_isCollateralERC20()? _collateralToken.balanceOf(account): account.balance);
    }

    /**
     * @dev     Transfer token from user if token is erc20 token.
     * @param   account     Address of account owner.
     * @param   rawAmount   Amount of token to be transferred into contract.
     */
    function _pullFromUser(address account, uint256 rawAmount)
        internal
    {
        require(rawAmount > 0, "amount is 0");
        if (_isCollateralERC20()) {
            _collateralToken.safeTransferFrom(account, address(this), rawAmount);
        } else {
            require(msg.value == rawAmount, "bad sent value");
        }
    }

    /**
     * @dev     Transfer token to user no matter erc20 token or ether.
     * @param   account     Address of account owner.
     * @param   rawAmount   Amount of token to be transferred to user.
     */
    function _pushToUser(address payable account, uint256 rawAmount)
        internal
    {
        require(rawAmount > 0, "amount is 0");
        if (_isCollateralERC20()) {
            _collateralToken.safeTransfer(account, rawAmount);
        } else {
            Address.sendValue(account, rawAmount);
        }
    }

    /**
     * @dev     Convert the represention of amount from raw to internal.
     * @param   rawAmount     Amount with decimals of token.
     * @return  Amount with internal decimals.
     */
    function _toInternalAmount(uint256 rawAmount) internal view returns (uint256) {
        return rawAmount.mul(_scaler);
    }

    /**
     * @dev     Convert the represention of amount from internal to raw.
     * @param   amount  Amount with internal decimals.
     * @return  Amount  with decimals of token.
     */
    function _toRawAmount(uint256 amount) internal view returns (uint256) {
        return amount.div(_scaler);
    }

    uint256[18] private __gap;
}
