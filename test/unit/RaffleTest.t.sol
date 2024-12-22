// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mock/LinkToken.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {EthanToken} from "../../src/EthanToken.sol";
import {EthanNft} from "../../src/EthanNft.sol";

contract RaffleTest is Test, CodeConstants {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 automationUpdateInterval;
    uint256 raffleEntranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;
    LinkToken link;
    EthanToken ethanToken;


    address public PLAYER = makeAddr("player");
    address public PLAYER0 = makeAddr("player0");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE); // 这个暂时就给玩家用来支付 gas 费(好像 anvil 上不需要这女的支付 gas?)

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        automationUpdateInterval = config.automationUpdateInterval;
        raffleEntranceFee = config.raffleEntranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        link = LinkToken(config.link);
        ethanToken = EthanToken(config.ethanToken);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subscriptionId, LINK_BALANCE);
        }
        link.approve(vrfCoordinatorV2_5, LINK_BALANCE);
        vm.stopPrank();

        vm.startPrank(PLAYER);
        ethanToken.mint(PLAYER, 100 ether);
        ethanToken.approve(address(raffle), raffleEntranceFee); // 首先要允许合约转移代币, 设计前端的时候需要注意这里
        vm.stopPrank();
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
            1. We check if the `msg.value` is high enough;
            2. We check if the `RaffleState` is `OPEN`;
            3. If all of the above are `true` then the `msg.sender` should be pushed in the `s_players` array;
            4. Our function emits the `EnteredRaffle` event.
    //////////////////////////////////////////////////////////////*/

    function testtestRaffleRevertsWHenYouDontRegister() public {
        // Arrange
        // Act / Assert
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotRegistered.selector);
        raffle.enterRaffle();
    }

    function testRaffleRevertsWHenYouDontPayEnought() public {
        // Arrange
        vm.startPrank(PLAYER0);
        // Act / Assert
        // 每个函数、事件、或者错误都有一个唯一的 selector，它是前 4 个字节的哈希值，用于标识特定的函数、事件或错误。
        // 通过 expectRevert 和 .selector，不仅预期 enterRaffle() 函数会 revert，还精确地检查是否抛出了特定的自定义错误。
        raffle.register();
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
        vm.stopPrank();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.startPrank(PLAYER);
        // Act
        raffle.register();
        raffle.enterRaffle();
        vm.stopPrank();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        // Arrange
        vm.startPrank(PLAYER);

        // Act / Assert
        raffle.register();
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEnter(PLAYER);
        raffle.enterRaffle();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.startPrank(PLAYER);
        raffle.register();
        raffle.enterRaffle();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.stopPrank();

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECKUPKEEP
    //////////////////////////////////////////////////////////////*/

    modifier raffleRegistered() {
        vm.prank(PLAYER);
        raffle.register();
        _;
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public raffleRegistered {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");  // perform it so that s_raffleState = RaffleState.CALCULATING
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public raffleRegistered {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle();
        vm.warp(block.timestamp + automationUpdateInterval - 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public raffleRegistered {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORMUPKEEP
    //////////////////////////////////////////////////////////////*/
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleRegistered {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        // It doesnt revert
        // using `vm.expectEmit()` and `emit ...` are unconvinient, because the parameter doesn't exist here
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public raffleRegistered {
        // Arrange
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, numPlayers, rState)
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleRegistered {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // 0 = open, 1 = calculating
    }

    /*//////////////////////////////////////////////////////////////
                           FULFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() public raffleRegistered raffleEntered skipFork {
        // Arrange
        // Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // vm.mockCall could be used here...
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(0, address(raffle));

        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(1, address(raffle));
    }

    // the biggest and happiset case
    function testFulfillRandomWordsPicksAWinnerResetsAndMintNft() public raffleRegistered raffleEntered skipFork {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            address player = address(uint160(i));
            vm.startPrank(player);
            raffle.register();
            ethanToken.mint(player, 100 ether); 
            ethanToken.approve(address(raffle), raffleEntranceFee);
            raffle.enterRaffle();
            vm.stopPrank();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();

        // Act
        vm.recordLogs(); // recording the event of performUpkeep
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(entries[1].topics[1]);
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(uint256(requestId), address(raffle));
        console2.logUint(raffle.randomNum());
        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        EthanNft ethanNft = raffle.getEthanNft();

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(endingTimeStamp > startingTimeStamp);
        assert(ethanNft.ownerOf(ethanNft.getTokenCounter() -1 ) == recentWinner);
    }
}

