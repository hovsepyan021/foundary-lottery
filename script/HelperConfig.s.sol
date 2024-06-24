// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 ticketPrice;
        uint256 lotteryInterval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        uint256 deployerKey;
    }

    NetworkConfig public activeConfig;

    constructor() {
        if(block.chainid == 11155111){
            activeConfig = getSepoliaEthConfig();
        } else if(block.chainid == 1) {

        } else {
            activeConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public returns (NetworkConfig memory) {
        return NetworkConfig({
            ticketPrice: 0.01 ether,
            lotteryInterval: 30,
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if(activeConfig.vrfCoordinator != address(0)) {
            return activeConfig;
        }
        uint96 baseFee = 0.25 ether;
        uint96 gasPriceLink = 1e9; // 1 gwei

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinator = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();
        return NetworkConfig({
            ticketPrice: 0.01 ether,
            lotteryInterval: 30,
            vrfCoordinator: address(vrfCoordinator),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: address(link),
            deployerKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        });
    }
}
