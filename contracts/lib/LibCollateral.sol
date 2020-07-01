pragma solidity 0.6.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";


interface IDecimals {
    function decimals() public view returns (uint8);
}

library LibCollateral {
    using LibMathSigned for int256;
    using SafeERC20 for IERC20;

    struct Collateral {
        IERC20 instance;
        uint256 scaler;
    }

    function initialize(Collateral storage collateral, address instance, uint8 decimals) internal {
        require(collateral.scaler == 0, "alreay initialized");
        require(decimals <= MAX_DECIMALS, "given decimals out of range");
        if (instance == address(0)) {
            // ether
            require(decimals == 18, "ether must have decimals of 18");
        } else {
            // erc20 token
            (uint8 retrievedDecimals, bool ok) = decimals(instance);
            require(!ok || (ok && retrievedDecimals == decimals), "decimals not match");
        }
        collateral.instance = instance;
        collateral.scaler = int256(10**(MAX_DECIMALS - decimals));
    }

    function decimals(address instance) internal returns (uint8, false) {
        try IDecimals(instance).decimals() returns (uint8 retrievedDecimals) {
            return (retrievedDecimals, true);
        } catch Error(string memory) {
            return (0, false);
        } catch (bytes memory) {
            return (0, false);
        }
    }

    // ** All interface call from upper layer use the decimals of the instance, called 'rawAmount'.

    /**
     * @dev Indicates that whether current instance is an erc20 token.
     * @return True if current instance is an erc20 token.
     */
    function isToken(Collateral storage collateral) internal view returns (bool) {
        return collateral.instance.address != address(0);
    }

    /**
     * @dev Transfer instance from user if instance is erc20 token.
     *
     * @param trader Address of account owner.
     * @param amount Amount of instance to be transferred into contract.
     * @return Internal representation of the raw amount.
     */
    function pull(
        Collateral storage collateral,
        address trader,
        uint256 amount
    )
        internal
        returns (uint256)
    {
        require(amount > 0, "amount should not be 0");
        uint256 rawAmount = toRaw(amount);
        if (isToken(collateral)) {
            instance.safeTransferFrom(trader, this.address, rawAmount);
        } else {
            require(msg.value == rawAmount, "amount not match with sent value");
        }
        return rawAmount;
    }

    /**
     * @dev Transfer instance to user no matter erc20 token or ether.
     *
     * @param trader    Address of account owner.
     * @param rawAmount Amount of instance to be transferred to user.
     * @return Internal representation of the raw amount.
     */
    function push(
        Collateral storage collateral,
        address payable trader,
        uint256 amount
    )
        internal
        returns (uint256)
    {
        require(amount > 0, "amount should not be 0");
        uint256 rawAmount = toRaw(amount);
        if (isToken(collateral)) {
            collateral.instance.safeTransfer(trader, rawAmount);
        } else {
            Address.sendValue(trader, rawAmount);
        }
        return rawAmount;
    }

    /**
     * @dev Convert the represention of amount from raw to internal.
     *
     * @param rawAmount Amount with decimals of instance.
     * @return Amount with internal decimals.
     */
    function toInternal(Collateral storage collateral, uint256 rawAmount) internal view returns (int256) {
        return rawAmount.toInt256().mul(collateral.scaler);
    }

    /**
     * @dev Convert the represention of amount from internal to raw.
     *
     * @param amount Amount with internal decimals.
     * @return Amount with decimals of instance.
     */
    function toRaw(Collateral storage collateral, int256 amount) internal view returns (uint256) {
        return amount.div(collateral.scaler).toUint256();
    }
}
