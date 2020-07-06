// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

library LibTypes {
    enum Side {FLAT, SHORT, LONG}

    enum Status {NORMAL, EMERGENCY, SETTLED}

    function counterSide(Side side) internal pure returns (Side) {
        if (side == Side.LONG) {
            return Side.SHORT;
        } else if (side == Side.SHORT) {
            return Side.LONG;
        }
        return side;
    }

    struct MarginAccount {
        Side side;
        uint256 size;
        uint256 entryValue;
        int256 entrySocialLoss;
        int256 entryFundingLoss;
        int256 cashBalance;
    }
}
