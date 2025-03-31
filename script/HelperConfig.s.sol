// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    // VRFCoordinatorV2_5Mock constants
    uint96 MOCK_BASE_FEE = 100 gwei;
    uint96 MOCK_GAS_PRICE = 100 gwei; //
    int256 MOCK_WEI_PER_UNIT_LINK = 4e15;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId(uint256 chainId);

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
        address linkTokenAddress;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfig() public returns (HelperConfig.NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return getSepoliaEthConfig();
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
            // which makes a mockup VRFCoordinator
        } else {
            revert HelperConfig__InvalidChainId(chainId);
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500_000,
            subscriptionId: 72858875755442345721962640812149195646793090510888592501724168333379984235327, // if 0, it would be created and funded in the DeployRaffle contract
            linkTokenAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0xbECe667788047174357710aD42ff4D4D536A7c51
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // if config is already created, return it
        if (networkConfigs[LOCAL_CHAIN_ID].callbackGasLimit != 0) {
            return networkConfigs[LOCAL_CHAIN_ID];
        } else {
            // otherwise create it and save it to the HelperConfig mapping
            // create a mockup VRFCoordinator
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock vrfCoordinator =
                new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE, MOCK_WEI_PER_UNIT_LINK);
            LinkToken linkToken = new LinkToken();

            //call addConsumer function to add the consumer
            // done during deploy script
            vm.stopBroadcast();

            networkConfigs[LOCAL_CHAIN_ID] = NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: address(vrfCoordinator), //
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // doesnt matter for mock, dgaf
                callbackGasLimit: 500_000,
                subscriptionId: 0, // will be changed in DeployRaffle
                linkTokenAddress: address(linkToken), // anvil-deployed link token
                account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
            });

            // then return the config
            return networkConfigs[LOCAL_CHAIN_ID];
        }
    }
}
