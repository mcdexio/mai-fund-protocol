// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

contract State is Initializable {

    enum FundState { NORMAL, EMERGENCY, SHUTDOWN }

    FundState internal _state;

    event UpdateState(FundState newState);

    function __State_init_unchained() internal initializer {
        _state = FundState.NORMAL;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is in specified state.
     */
    modifier whenInState(FundState state) {
        require(_state == state, "bad state");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is *NOT* in specified state.
     */
    modifier whenNotInState(FundState state) {
        require(_state != state, "bad state");
        _;
    }

    /**
     * @dev     Set state to emergency, only available in Normal state.
     */
    function _setEmergency()
        internal
        virtual
        whenInState(FundState.NORMAL)
    {
        _state = FundState.EMERGENCY;
        emit UpdateState(FundState.EMERGENCY);
    }

    /**
     * @dev     Set state to shutdown, only available in shutdown state.
     */
    function _setShutdown()
        internal
        virtual
        whenInState(FundState.EMERGENCY)
    {
        _state = FundState.SHUTDOWN;
        emit UpdateState(FundState.SHUTDOWN);
    }

    uint256[19] private __gap;
}