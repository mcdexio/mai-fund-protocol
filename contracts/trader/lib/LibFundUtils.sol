pragma solidity 0.6.10;

library LibFundUtils {
    /**
     * @dev Get current timestamp.
     */
    function currentTime() internal view returns (uint256) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}