// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../lib/LibConstant.sol";
import "../storage/FundStorage.sol";

interface ITokenWithDecimals {
    function decimals() external view returns (uint8);
}

contract FundCollateral is FundStorage {
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using SafeERC20 for IERC20;

    function initializedCollateral(address collateral, uint8 decimals) internal {
        require(_scaler == 0, "alreay initialized");
        require(decimals <= LibConstant.MAX_COLLATERAL_DECIMALS, "given decimals out of range");
        if (collateral == address(0)) {
            // ether
            require(decimals == 18, "ether must have decimals of 18");
        } else {
            // erc20 token
            (uint8 retrievedDecimals, bool ok) = retrieveDecimals(collateral);
            require(!ok || (ok && retrievedDecimals == decimals), "decimals not match");
        }
        _collateral = collateral;
        _scaler = uint256(10**(LibConstant.MAX_COLLATERAL_DECIMALS.sub(decimals)));
    }

    function retrieveDecimals(address token) internal view returns (uint8, bool) {
        try ITokenWithDecimals(token).decimals() returns (uint8 retrievedDecimals) {
            return (retrievedDecimals, true);
        } catch Error(string memory) {
            return (0, false);
        } catch (bytes memory) {
            return (0, false);
        }
    }

    // ** All interface call from upper layer use the decimals of the token, called 'rawAmount'.

    /**
     * @dev Indicates that whether current token is an erc20 token.
     * @return True if current token is an erc20 token.
     */
    function isToken() internal view returns (bool) {
        return _collateral != address(0);
    }

    /**
     * @dev Transfer token from user if token is erc20 token.
     *
     * @param trader Address of account owner.
     * @param amount Amount of token to be transferred into contract.
     * @return Internal representation of the raw amount.
     */
    function pullCollateral(address trader, uint256 amount) internal returns (uint256) {
        require(amount > 0, "amount should not be 0");
        uint256 rawAmount = toRaw(amount);
        if (isToken()) {
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
    function pushCollateral(address payable trader, uint256 amount) internal returns (uint256) {
        require(amount > 0, "amount should not be 0");
        uint256 rawAmount = toRaw(amount);
        if (isToken()) {
            IERC20(_collateral).safeTransfer(trader, rawAmount);
        } else {
            Address.sendValue(trader, rawAmount);
        }
        return rawAmount;
    }

    /**
     * @dev Convert the represention of amount from raw to internal.
     *
     * @param rawAmount Amount with decimals of token.
     * @return Amount with internal decimals.
     */
    function toInternal(uint256 rawAmount) internal view returns (uint256) {
        return rawAmount.mul(_scaler);
    }

    /**
     * @dev Convert the represention of amount from internal to raw.
     *
     * @param amount Amount with internal decimals.
     * @return Amount with decimals of token.
     */
    function toRaw(uint256 amount) internal view returns (uint256) {
        return amount.div(_scaler);
    }
}
