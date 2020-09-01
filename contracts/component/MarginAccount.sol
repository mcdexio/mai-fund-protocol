// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../interface/IPerpetual.sol";
import "./Context.sol";

interface IOwnable {
    function owner() external view returns (address);
}

/**
 * @title   MarginAccount
 * @notice  Handle all interactions with underlaying perpetual.
 */
contract MarginAccount is Initializable, Context {

    using SafeCast for int256;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IPerpetual internal _perpetual;

    function __MarginAccount_init_unchained(address perpetualAddress)
        internal
        initializer
    {
        require(perpetualAddress != address(0), "zero perpetual address");
        _perpetual = IPerpetual(perpetualAddress);
    }

    /**
     * @dev Get owner of perpetual system (Owner of GlobalConfig)
     */
    function _owner()
        internal
        view
        virtual
        returns (address)
    {
        return IOwnable(_perpetual.globalConfig()).owner();
    }

    /**
     * @dev Should be same to perpetual.collateral()
     */
    function _collateral()
        internal
        view
        virtual
        returns (address)
    {
        return _perpetual.collateral();
    }

    /**
     * @dev Current mark price from perpetual.
     */
    function _markPrice()
        internal
        virtual
        returns (uint256)
    {
        return _perpetual.markPrice();
    }

    /**
     * @dev Address of perpetual.
     */
    function _perpetualAddress()
        internal
        view
        virtual
        returns (address)
    {
        return address(_perpetual);
    }

    /**
     * @dev True If perpetual in emergency mode.
     */
    function _emergency()
        internal
        view
        virtual
        returns (bool)
    {
        return _perpetual.status() != LibTypes.Status.NORMAL;
    }

    /**
     * @notice  Return margin account of fund.
     * @return  account   Margin account structure.
     */
    function _marginAccount()
        internal
        view
        virtual
        returns (LibTypes.MarginAccount memory account)
    {
        account = _perpetual.getMarginAccount(_self());
    }

    /**
     * @dev     Return total collateral amount, including unclaimed fee.
     *          This is NOT a view function because [marginBalance]
     * @return  Value of total collateral in fund.
     */
    function _totalAssetValue()
        internal
        virtual
        returns (uint256)
    {
        int256 marginBalance = _perpetual.marginBalance(_self());
        require(marginBalance >= 0, "negative marginBalance");
        return marginBalance.toUint256();
    }

    /**
     * @dev     Deposit collateral to perpetual.
     */
    function _deposit(uint256 rawAmount)
        internal
    {
        _perpetual.deposit{ value: msg.value }(rawAmount);
    }

    function _settle()
        internal
    {
        _perpetual.settle();
    }

    /**
     * @dev     Withdraw collateral from perpetual.
     */
    function _withdraw(uint256 rawAmount)
        internal
    {
        _perpetual.withdraw(rawAmount);
    }

    /**
     * @notice bid share from redeeming or shutdown account.
     * @param   side            Side of taker wants to bid.
     * @param   price           Bidding price.
     * @param   positionAmount  Amount of position to bid.
     */
    function _tradePosition(
        address taker,
        address maker,
        LibTypes.Side side,
        uint256 price,
        uint256 positionAmount
    )
        internal
    {
        // align to lotsize
        uint256 lotSize = _perpetual.getGovernance().lotSize;
        uint256 alignedAmount = positionAmount.sub(positionAmount.mod(lotSize));
        (
            uint256 takerOpened,
            uint256 makerOpened
        ) = _perpetual.tradePosition(
            taker,
            maker,
            side,
            price,
            alignedAmount
        );
        // check safety of trading margin account.
        if (makerOpened > 0) {
            require(_perpetual.isIMSafe(maker), "maker im unsafe");
        } else {
            require(_perpetual.isSafe(maker), "maker unsafe");
        }
        if (takerOpened > 0) {
            require(_perpetual.isIMSafe(taker), "taker im unsafe");
        } else {
            require(_perpetual.isSafe(taker), "taker unsafe");
        }
    }

    uint256[19] private __gap;
}