// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./LibConstant.sol";
import "./LibMathEx.sol";

library LibUtils {

    using SafeMath for uint256;
    using LibMathEx for uint256;
    /**
     * @dev Get current timestamp.
     */
    function currentTime() internal view returns (uint256) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }

    /**
     * @dev Annualized fee rate.
     */
    function annualizedFeeRate(uint256 feeRate, uint256 lastFeeTime) internal view returns (uint256) {
        uint256 timeElapsed = LibUtils.currentTime().sub(lastFeeTime);
        return feeRate.wfrac(timeElapsed, LibConstant.SECONDS_PER_YEAR);
    }

}