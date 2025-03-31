// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Raffle} from "src/Raffle.sol";

/**
 * @title   CreateSubscription contract for creating a VRF subscription
 * @dev     As VRFCoordinatorV2_5Mock.createSubscription() has same signature as eth sepolia vrf coordinators createSubcription() function, this will work for both eth sepolia and local chain
 * @notice  Has functions to create a subscription for a VRF coordinator for the current network
 */
contract CreateSubscription is Script {
    function setUp() public {}

    function run() public {
        createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subscriptionId,) = createSubscription(vrfCoordinator, account);
        return (subscriptionId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint256, address) {
        console2.log("Creating subscription on chain ID %s", block.chainid);
        vm.startBroadcast(account);
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console2.log("Subscription ID is %s", subscriptionId);
        console2.log("Please update the subscription ID in the HelperConfig contract");
        return (subscriptionId, vrfCoordinator);
    }
}

/**
 * @title   FundSubscription contract for funding a VRF subscription
 * @dev     Used by DeployRaffle contract to fund a subscription for a VRF coordinator
 * @notice  Gives two functions to fund a subscription for a VRF coordinator
 */
contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 10 ether; // same as 63e18, if used as LINK tokens amout this represents 3 LINK tokens, LINK has 18 decimals precision

    function setUp() public {}

    function run() public {
        fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().linkTokenAddress;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account) public {
        console2.log("Funding subscription on chain ID %s", block.chainid);
        console2.log("Using vrfCoordinator %s", vrfCoordinator);
        console2.log("On ChainId %s\n", block.chainid);

        // ues transfer and call to fund the subscription on sepolia chain case
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT); // fund 3e18 , i.e. 3 LINK
        } else if (block.chainid == ETH_SEPOLIA_CHAIN_ID) {
            vm.startBroadcast(account);
            /*
            1. transferAndCall(address _to, uint256 _value, bytes memory _data)
            2. onTokenTransfer is called by the link token on the receiver contract if it's a contract (vrf coordinator contract's on token transfer handler)
            */
            // the vrfCoordinator will add the LINK tokens transfer as balance to the subscription with the given subscriptionId
            // sends token to the LINK token created by the HelperConfig
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
        } else {
            console2.log("Chain ID %s not supported", block.chainid);
        }
        vm.stopBroadcast();
        console2.log("Subscription %s funded", subscriptionId);
    }
}
/**
 * @title   AddConsumer contract for adding a consumer to a VRF subscription
 * @dev     Used to add a consumer contract to a VRF subscription
 * @notice  Gives two functions to add a consumer to a VRF subscription
 */

contract AddConsumer is Script {
    function setUp() public {}

    // gets latest deployed raffle contract
    function run() public {
        address raffleAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(raffleAddress);
    }

    function addConsumerUsingConfig(address raffleAddress) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address account = helperConfig.getConfig().account;
        addConsumer(raffleAddress, vrfCoordinator, subscriptionId, account);
    }

    function addConsumer(address raffleAddress, address vrfCoordinator, uint256 subscriptionId, address account) public {
        console2.log("Adding consumer to subscription on chain ID %s", block.chainid);
        console2.log("Using vrfCoordinator %s", vrfCoordinator);
        console2.log("Adding to Subscription ID: %s", subscriptionId);
        console2.log("Consumer address: %s\n", raffleAddress);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, raffleAddress);
        vm.stopBroadcast();
        console2.log("Consumer added to subscription %s", subscriptionId);
    }
}
