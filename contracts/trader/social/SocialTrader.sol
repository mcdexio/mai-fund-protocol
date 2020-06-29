pragma solidity 0.6.10;

import "../TraderBase.sol";
import "../Fund.sol";

import "../../lib/LibFundStorage.sol";
import "../../lib/LibFundUtils.sol";

contract SocialTrader is TraderBase, Fund {

    /**
        for fund manager:
            - claim incentive fee   (manager)
                - performance fee
                - streaming fee
            - pause fund            (manager, administrator)
     */

    /**
     * @dev Calculate incentive fee (streaming fee + performance fee)
     * @return Collateral amount of total fee to claim.
     */
    function getIncentiveFees() external view returns (uint256) {
        return _fundStorage.getFee();
    }

    /**
     * @dev Claim incentive fee (streaming fee + performance fee).
     */
    function claimIncentiveFee() external onlyManager {
        // ensure claiming period >= feeClaimingPeriod (configuration)
        require(_fundStorage.isCooldown(fundStorage), "claiming not cooldown");
        // check time is valid.
        require(
            fundStorage.manager.lastClaimingTimestamp < LibFundUtils.currentTime(),
            "future claiming time"
        );
        // get fees
        (
            uint256 newNetValue,
            uint256 streamingFee,
            uint256 performanceFee
        ) = _fundStorage.getFees(fundStorage);
        // transferBalance
        uint256 fee = streamingFee.add(performanceFee);
        if (fee > 0) {
            claimCashBalance(fee);
        }
        // update time and hwm
        fundStorage.manager.lastFeeHighWaterMark = newNetValue;
        fundStorage.manager.lastFeeTimestamp = LibUtils.currentTime();
    }
}