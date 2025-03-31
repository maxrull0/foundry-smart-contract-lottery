/*
 Testing stages:
    unit tests: test a single contract in isolation
    integration tests: test the interaction between multiple contracts
    staging on a testnet: test the interaction between multiple contracts on a testnet
    live: test the interaction between multiple contracts on mainnet

    fuzzing
    stateful fuzzing
    stateless fuzzing
    formal verification

*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";


/**
 * @author  .
 * @title   Raffle Integrations Test for testing interactions between the Raffle contract and other contracts such as VRF Coordinator, LinkToken, and Chainlink Keepers
 * @dev     .
 * @notice  .
 */

contract IntegrationsTest is Test {



    
}