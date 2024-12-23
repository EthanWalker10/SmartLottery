// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "./Interactions.s.sol";

// 根据 chainId 获取/生成 Raffle 需要的配置参数, 然后部署 Raffle 合约
contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        AddConsumer addConsumer = new AddConsumer();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinatorV2_5) =
                createSubscription.createSubscription(config.vrfCoordinatorV2_5, config.account);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinatorV2_5, config.subscriptionId, config.link, config.account
            );

            helperConfig.setConfig(block.chainid, config);
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.subscriptionId,
            config.gasLane,
            config.automationUpdateInterval,
            config.raffleEntranceFee,
            config.callbackGasLimit,
            config.vrfCoordinatorV2_5,
            config.ethanToken,
            config.initialTokenUri
        );
        vm.stopBroadcast();

        // We already have a broadcast in here
        addConsumer.addConsumer(address(raffle), config.vrfCoordinatorV2_5, config.subscriptionId, config.account);
        return (raffle, helperConfig);
    }
}

// 需要的参数
// constructor(
//         uint256 subscriptionId,
//         bytes32 gasLane, // keyHash
//         uint256 interval,
//         uint256 entranceFee,
//         uint32 callbackGasLimit,
//         address vrfCoordinatorV2,
//         address token,
//         string memory initialTokenUri
//     ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
//         i_subscriptionId = subscriptionId;
//         i_gasLane = gasLane;
//         i_interval = interval;
//         i_entranceFee = entranceFee;
//         s_raffleState = RaffleState.OPEN;
//         s_lastTimeStamp = block.timestamp;
//         i_callbackGasLimit = callbackGasLimit;
//         i_token = token;
//         i_initialTokenUri = initialTokenUri;
//         i_nft = new EthanNft(i_initialTokenUri);
//     }