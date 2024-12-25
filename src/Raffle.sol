// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// VRF: Verifiable Random Function

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol"; // Interface for VRF
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol"; // 用来导入 RandomWordsRequest 结构体
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EthanNft} from "./EthanNft.sol";

/**
 * @title A Lottery Game using EthanToken For EthanNft 
 * @author Ethan Walker
 * @notice based on chainlink VRF and Automation
 * @notice EthanToken here, EthanNft to winner
 */

contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /* Errors */
    error Raffle__NotRegistered();
    error Raffle__WrongBuyAmount();
    error Raffle__UpkeepNotNeeded(uint256 numPlayers, uint256 raffleState);
    error Raffle__TransferFailed();
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__RaffleNotOpen();

    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State variables */
    // Chainlink VRF Variables
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;


    // Lottery Variables
    uint256 private immutable i_interval;
    uint256 private immutable i_entranceFee;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    address[] private s_players;
    address[] private s_allUsers;
    mapping(address => bool) public balances;
    RaffleState private s_raffleState;

    // Token Variables
    address private immutable i_token; 
    EthanNft private immutable i_nft;
    string private i_initialTokenUri;
    uint256 private constant SELL_AMOUNT = 1e15;
    uint256 private constant BUY_AMOUNT = 1e18;


    /* Events */
    event RequestedRaffleWinner(uint256 indexed requestId); // only for testing, commenting it out when deploying
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);
    event RaffleBuyOneToken(address indexed player);
    event RaffleRegister(address indexed player);


    /* Functions */
    // cause Raffle inherits VRFConsumerBaseV2Plus, we need to pass corresponding params to the constructor of it
    // param `vrfCoordinator` is the address of VRFCoordinator contract
    constructor(
        uint256 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2,
        address token,
        string memory initialTokenUri
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_interval = interval;
        i_entranceFee = entranceFee;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
        i_token = token;
        i_initialTokenUri = initialTokenUri;
        i_nft = new EthanNft(i_initialTokenUri);
    }

    /**
     * Registration
     */
    function register() public {
        s_allUsers.push(msg.sender);
        balances[msg.sender] = true;
        emit RaffleRegister(msg.sender);
    }

    function buy() public payable {
        if (msg.value != SELL_AMOUNT) {
            revert Raffle__WrongBuyAmount();
        }
        IERC20(i_token).transfer(msg.sender, BUY_AMOUNT);
        emit RaffleBuyOneToken(msg.sender);
    }

    function enterRaffle() public {
        if (!balances[msg.sender]) {
            revert Raffle__NotRegistered();
        }
        if (IERC20(i_token).balanceOf(msg.sender) < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        bool success = IERC20(i_token).transferFrom(msg.sender, address(this), i_entranceFee);
        if (!success) {
            revert Raffle__TransferFailed();
        }
        s_players.push(msg.sender);
        emit RaffleEnter(msg.sender);
    }

    /**
     * The function that the Keeper nodes call, which look for `upkeepNeeded` to return True.
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timePassed && isOpen && hasPlayers);
        return (upkeepNeeded, "0x0"); 
    }
    /**
     * @dev Once `checkUpkeep` is returning `true`, this function is called
     * and it kicks off a Chainlink VRF call to get a random winner.
     */
    function performUpkeep(bytes calldata /* performData */ ) external override {
        // if anyone else calls it directly but nothing is checked
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(s_players.length, uint256(s_raffleState));
        }

        // change the state of the Raffle when picking the winner
        s_raffleState = RaffleState.CALCULATING;

        // Will revert if subscription is not set and funded.
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane, 
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // use ETH when sepolia
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true}) 
                    // use link when anvil
                    // VRFV2PlusClient.ExtraArgsV1({nativePayment: false}) 
                )
            })
        );
        // only for testing, commenting out it when deploying
        emit RequestedRaffleWinner(requestId);
    }

    /**
     * @dev the function that Chainlink VRF node calls to send the money to the random winner.
     */
    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        // restart
        s_players = new address payable[](0);
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(recentWinner);
        // EthanNft for winner
        EthanNft(i_nft).mintNft(recentWinner);
    }

    /**
     * Getter Functions
     */
    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getEthanNft() public view returns (EthanNft) {
        return i_nft;
    }
}