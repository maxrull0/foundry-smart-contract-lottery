// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title RevertReceiver
 * @notice A mock contract that reverts on all ETH transfers
 * @dev Used for testing failure cases when transferring ETH
 */
contract RevertReceiver {
    // Custom error for better gas efficiency
    error RevertReceiver__ReceiveRejected();
    error RevertReceiver__FallbackRejected();
    
    /**
     * @notice Reverts when receiving plain ETH transfers
     */
    receive() external payable {
        revert RevertReceiver__ReceiveRejected();
    }
    
    /**
     * @notice Reverts when receiving ETH with calldata
     */
    fallback() external payable {
        revert RevertReceiver__FallbackRejected();
    }
}
