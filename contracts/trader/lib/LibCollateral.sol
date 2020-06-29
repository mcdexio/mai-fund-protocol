pragma solidity 0.6.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";


interface IDecimals {
    function decimals() public view returns (uint8);
}

library LibCollateral {
    using LibMathSigned for int256;
    using SafeERC20 for IERC20;

    struct CollateralSpec {
        IERC20 collateral;
        uint256 scaler;
    }

    function initialize(CollateralSpec storage spec, address collateral, uint8 decimals) internal {
        require(spec.scaler == 0, "alreay initialized");
        require(decimals <= MAX_DECIMALS, "given decimals out of range");
        if (collateral == address(0)) {
            // ether
            require(decimals == 18, "ether must have decimals of 18");
        } else {
            // erc20 token
            (uint8 retrievedDecimals, bool ok) = getDecimals(collateral);
            require(!ok || (ok && retrievedDecimals == decimals), "decimals not match");
        }
        spec.collateral = collateral;
        spec.scaler = int256(10**(MAX_DECIMALS - decimals));
    }

    function getDecimals(address collateral) internal returns (uint8, false) {
        try IDecimals(collateral).decimals() returns (uint8 retrievedDecimals) {
            return (retrievedDecimals, true);
        } catch Error(string memory) {
            return (0, false);
        } catch (bytes memory) {
            return (0, false);
        }
    }

    // ** All interface call from upper layer use the decimals of the collateral, called 'rawAmount'.

    /**
     * @dev Indicates that whether current collateral is an erc20 token.
     * @return True if current collateral is an erc20 token.
     */
    function isToken(CollateralSpec storage spec) internal view returns (bool) {
        return spec.collateral.address != address(0);
    }

    /**
     * @dev Transfer collateral from user if collateral is erc20 token.
     *
     * @param trader    Address of account owner.
     * @param rawAmount Amount of collateral to be transferred into contract.
     * @return Internal representation of the raw amount.
     */
    function pullCollateral(
        CollateralSpec storage spec,
        address trader,
        uint256 rawAmount
    )
        internal
    {
        require(rawAmount > 0, "amount should not be 0");
        if (isToken(spec)) {
            collateral.safeTransferFrom(trader, this.address, rawAmount);
        } else {
            require(msg.value == rawAmount, "amount not match with sent value");
        }
    }

    /**
     * @dev Transfer collateral to user no matter erc20 token or ether.
     *
     * @param trader    Address of account owner.
     * @param rawAmount Amount of collateral to be transferred to user.
     * @return Internal representation of the raw amount.
     */
    function pushCollateral(
        CollateralSpec storage spec,
        address payable trader,
        uint256 rawAmount
    )
        internal
    {
        require(rawAmount > 0, "amount should not be 0");
        if (isToken(spec)) {
            spec.collateral.safeTransfer(trader, rawAmount);
        } else {
            Address.sendValue(trader, rawAmount);
        }
    }

    /**
     * @dev Convert the represention of amount from raw to internal.
     *
     * @param rawAmount Amount with decimals of collateral.
     * @return Amount with internal decimals.
     */
    function toInternal(CollateralSpec storage spec, uint256 rawAmount) internal view returns (int256) {
        return rawAmount.toInt256().mul(spec.scaler);
    }

    /**
     * @dev Convert the represention of amount from internal to raw.
     *
     * @param amount Amount with internal decimals.
     * @return Amount with decimals of collateral.
     */
    function toRaw(CollateralSpec storage spec, int256 amount) internal view returns (uint256) {
        return amount.div(spec.scaler).toUint256();
    }
}
