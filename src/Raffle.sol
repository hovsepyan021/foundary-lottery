// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A simple raffle contract
 * @author Oleg Hovsepyan
 * @notice  This is a simple raffle contract.
 * @dev Implements Chainink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughEthSent();
    error Raffle__IntervalNotPassed();
    error Raffle__WinnerTransferFailed();
    error Raffle__NotOpen();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 state);

    enum RaffleState {
        OPEN,
        CALCULATING_WINNER
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUMBER_OF_WORDS = 1;

    uint256 private immutable i_ticketPrice;
    uint256 private immutable i_lotteryInterval;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint256 private s_lastLotteryTime;
    address payable private s_lastLotteryWinner;
    address payable[] private s_players;
    RaffleState private s_raffleState;

    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 ticketPrice,
        uint256 lotteryInterval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_ticketPrice = ticketPrice;
        i_lotteryInterval = i_lotteryInterval;
        s_lastLotteryTime = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_ticketPrice) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() public {
        if (block.timestamp - s_lastLotteryTime <= i_lotteryInterval) {
            revert Raffle__IntervalNotPassed();
        }
        s_raffleState = RaffleState.CALCULATING_WINNER;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUMBER_OF_WORDS
        );
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        uint256 nextRandomNumber = _randomWords[0];
        uint256 winnerIndex = nextRandomNumber % s_players.length;
        s_lastLotteryWinner = s_players[winnerIndex];
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastLotteryTime = block.timestamp;
        (bool success,) = s_lastLotteryWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__WinnerTransferFailed();
        }
        emit WinnerPicked(s_lastLotteryWinner);
    }

    function getTicketPrice() public view returns (uint256) {
        return i_ticketPrice;
    }

    //*
    //* This function is called by the VRF Coordinator to check if the upkeep is needed
    // Condition is the following
    // 1) At least we have 1 player
    // 2) It's time to do that
    // 3) The Raffle is in open state
    function checkUpkeep(bytes memory) public view returns (bool upkeepNeeded, bytes memory) {
        bool timeHasPassed = (block.timestamp - s_lastLotteryTime > i_lotteryInterval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasPlayers;
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (upkeepNeeded) {
            pickWinner();
        } else {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
    }

    function getState() external returns(RaffleState) {
        return s_raffleState;
    }

    function getPlayers() external returns(address  payable[] memory) {
        return s_players;
    }

}
