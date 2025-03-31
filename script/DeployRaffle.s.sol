// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract DeployRaffle is Script, CodeConstants {
    Raffle raffle;

    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig.NetworkConfig memory) {
        // local -> deploy mocks, get local config
        // sepolia -> get direct sepolia config
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        // 1. Create subscription for the consumer raffle contract.
        // For ETH Sepolia this will create a new subscription if on helperconfig the subscriptionId is still 0
        if (networkConfig.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (networkConfig.subscriptionId, networkConfig.vrfCoordinator) =
                createSubscription.createSubscription(networkConfig.vrfCoordinator, networkConfig.account);

            // Fund the subscription of the current networkConfig if less than 3 LINK
            // In local chain case, as previously only the subscriptionId was created, the subscription is funded here manually, not via the ...UsingConfig function
            if (LinkToken(networkConfig.linkTokenAddress).balanceOf(address(this)) < 3 ether) {
                // use fundSubscriptionUsingConfig() from the FundSubscription contract to fund 3 LINK on local or sepolia chain
                FundSubscription fundSubscription = new FundSubscription();
                fundSubscription.fundSubscription(
                    networkConfig.vrfCoordinator, networkConfig.subscriptionId, networkConfig.linkTokenAddress, networkConfig.account
                );
            }
        }

        vm.startBroadcast(networkConfig.account);
        // TODO: maybe add later devops to use the last deployed script in case of sepolia eth chain
        // currently do it manually as still testing only on local chain
        raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        // if created raffle is not added yet as a consumer to the vrfCoordinator, add it
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), networkConfig.vrfCoordinator, networkConfig.subscriptionId, networkConfig.account);

        return (raffle, networkConfig);
    }
}
