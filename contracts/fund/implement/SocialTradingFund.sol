// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

import "../Core.sol";
import "../Getter.sol";

interface IDelegatable {
    function setDelegator(address perpetual, address newDelegator) external;
    function isDelegator(address trader, address perpetual, address target) external view returns (bool);
}

/**
 * @title   Social trading fund, managed by a social trader.
 *          A social trader is able trade for fund but cannot withdraw from fund.
 */
contract SocialTradingFund is
    Initializable,
    Core,
    Getter
{
    using SafeMath for uint256;

    address internal _manager;

    event SetManager(address indexed oldManager, address indexed newManager);
    event WithdrawManagementFee(address indexed maintainer, uint256 totalFee);

    function initialize(
        string calldata name,
        string calldata symbol,
        uint8 collateralDecimals,
        address perpetual,
        uint256 cap
    )
        external
        initializer
    {
        __Core_init(name, symbol, collateralDecimals, perpetual, cap);
        __SocialTradingFund_init_unchained();
    }

    function __SocialTradingFund_init_unchained()
        internal
        initializer
    {
    }

    /**
     * @dev Manager of fund.
     */
    function manager()
        public
        view
        returns (address)
    {
        return _manager;
    }

    /**
     * @dev Calculate incentive fee (streaming fee + performance fee)
     * @return totalFee IncentiveFee gain since last claiming.
     */
    function managementFee()
        public
        returns (uint256 totalFee)
    {
        claimManagementFee();
        return _totalFeeClaimed;
    }

    /**
     * @notice  Set fund manager and delegator to an account.
     * @param   newManager      Address of manager.
     * @param   exchangeAddress Address of exchange.
     */
    function setManager(address newManager, address exchangeAddress)
        public
        onlyOwner
        nonReentrant
    {
        if (_manager != newManager) {
            if (_manager != address(0)) {
                _withdrawManagementFee(managementFee());
            }
            emit SetManager(_manager, newManager);
            _manager = newManager;
        }
        IDelegatable delegatable = IDelegatable(exchangeAddress);
        if (!delegatable.isDelegator(newManager, address(_perpetual), _self())) {
            delegatable.setDelegator(address(_perpetual), newManager);
        }
    }

    /**
     * @notice  In extreme case, there will not be enough collateral (may be liquidated) to withdraw.
     * @param   collateralAmount    Amount of collateral to withdraw.
     */
    function withdrawManagementFee(uint256 collateralAmount)
        public
        nonReentrant
        whenNotPaused
    {
        _withdrawManagementFee(collateralAmount);
    }

    /**
     * @dev     In extreme case, there will not be enough collateral (may be liquidated) to withdraw.
     * @param   collateralAmount    Amount of collateral to withdraw.
     */
    function _withdrawManagementFee(uint256 collateralAmount)
        internal
    {
        claimManagementFee();
        if (_totalFeeClaimed == 0) {
            return;
        }
        _totalFeeClaimed = _totalFeeClaimed.sub(collateralAmount, "insufficient fee");
        _withdraw(collateralAmount);
        _pushToUser(payable(_manager), collateralAmount);
        emit WithdrawManagementFee(_manager, collateralAmount);
    }

    /**
     * @dev Claim incentive fee (streaming fee + performance fee).
     */
    function claimManagementFee()
        public
        whenNotPaused
    {
        _netAssetValue();
    }

    uint256[19] private __gap;
}