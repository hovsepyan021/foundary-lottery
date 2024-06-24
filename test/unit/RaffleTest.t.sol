// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;

    address public PLAYER = makeAddr("Player");
    uint256 public constant USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
    }

    function testRaffleInitInOpenState() public {
        assert(raffle.getState() == Raffle.RaffleState.OPEN);
    }

    function testEnterRaffle_happyPath() public {
        hoax(PLAYER, USER_BALANCE);
        raffle.enterRaffle{value: 1 ether}();
        assert(address(raffle).balance == 1 ether);
        assert(raffle.getPlayers()[0] == PLAYER);
    }

    function testEnterRaffle_revertNotPaidEnough() public {
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        hoax(PLAYER, USER_BALANCE);
        raffle.enterRaffle{value: 0.001 ether}();
    }

    function testEmitsEventOnEnter() public {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.EnteredRaffle(PLAYER);

        hoax(PLAYER, USER_BALANCE);
        raffle.enterRaffle{value: 1 ether}();
    }

    function testRevertEnterWhenWinnerIsCalculating() public {
        hoax(PLAYER, USER_BALANCE);
        raffle.enterRaffle{value: 1 ether}();
        (,uint256 lotteryInterval,,,,,) = helperConfig.activeConfig();
        vm.warp(block.timestamp + lotteryInterval);
        vm.roll(block.number + 1);

        raffle.performUpkeep("0x0");

        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        hoax(PLAYER, USER_BALANCE);
        raffle.enterRaffle{value: 2 ether}();
    }

    function testCheckUpKeepTimeNotPassed() public {
        (bool isUpkeepNeeded,) = raffle.checkUpkeep("0x0");
        assertFalse(isUpkeepNeeded);
    }

    function testCheckUpKeepNoPlayers() public {
        (,uint256 lotteryInterval,,,,,) = helperConfig.activeConfig();
        vm.warp(block.timestamp + lotteryInterval);
        vm.roll(block.number + 1);
        (bool isUpkeepNeeded,) = raffle.checkUpkeep("0x0");
        assertFalse(isUpkeepNeeded);
    }

    function testCheckUpKeep_happyPath() public {
        hoax(PLAYER, USER_BALANCE);
        raffle.enterRaffle{value: 1 ether}();
        (,uint256 lotteryInterval,,,,,) = helperConfig.activeConfig();
        vm.warp(block.timestamp + lotteryInterval);
        vm.roll(block.number + 1);
        (bool isUpkeepNeeded,) = raffle.checkUpkeep("0x0");
        assertTrue(isUpkeepNeeded);
    }

    function testRevertEnterWhenUpKeepNotNeeded() public {
        hoax(PLAYER, USER_BALANCE);

        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 openRaffleState = 0;
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, openRaffleState));
        raffle.performUpkeep("0x0");
    }

    function testPerformUpKeepEventEmitted() public {
        hoax(PLAYER, USER_BALANCE);
        raffle.enterRaffle{value: 1 ether}();
        (,uint256 lotteryInterval,,,,,) = helperConfig.activeConfig();
        vm.warp(block.timestamp + lotteryInterval);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffle.performUpkeep("0x0");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];
        assert(uint256(requestId) > 0);
    }

    modifier raffleEnteredAndTimePassed() {
        hoax(PLAYER, USER_BALANCE);
        raffle.enterRaffle{value: 1 ether}();
        (,uint256 lotteryInterval,,,,,) = helperConfig.activeConfig();
        vm.warp(block.timestamp + lotteryInterval);
        vm.roll(block.number + 1);
        _;
    }

    function testFulfillRandomWordsCanBeCalledOnlyAfterPerformUpkeep(uint256 requestId) public raffleEnteredAndTimePassed {
        (,,address vrfCoordinator,,,,) = helperConfig.activeConfig();

        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
    }

    function testWholeFlow() public raffleEnteredAndTimePassed {
        uint256 additionalPlayers = 5;
        for(uint256 index = 1; index <= additionalPlayers; index++) {
            address nextAddress = address(uint160(index));
            hoax(nextAddress, 1 ether);
            raffle.enterRaffle{value: 1 ether}();
        }

        assert(address(raffle).balance == (additionalPlayers + 1) * 1 ether);

        vm.recordLogs();
        raffle.performUpkeep("0x0");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];

        (,,address vrfCoordinator,,,,) = helperConfig.activeConfig();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        assert(raffle.getState() == Raffle.RaffleState.OPEN);
        assert(address(raffle).balance == 0);
    }
}
