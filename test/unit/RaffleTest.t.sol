// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;

    address public PLAYER = makeAddr("Player");
    uint256 public constant USER_BALANE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
    }

    function testRaffleInitInOpenState() public {
        assert(raffle.getState() == Raffle.RaffleState.OPEN);
    }

    function testEnterRaffle_happyPath() public {
        hoax(PLAYER, USER_BALANE);
        raffle.enterRaffle{value: 1 ether}();
        assert(address(raffle).balance == 1 ether);
        assert(raffle.getPlayers()[0] == PLAYER);
    }

    function testEnterRaffle_revertNotPaidEnough() public {
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        hoax(PLAYER, USER_BALANE);
        raffle.enterRaffle{value: 0.001 ether}();
    }

    function testEmitsEventOnEnter() public {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.EnteredRaffle(PLAYER);

        hoax(PLAYER, USER_BALANE);
        raffle.enterRaffle{value: 1 ether}();
    }

    function testRevertEnterWhenWinnerIsCalculating() public {
        hoax(PLAYER, USER_BALANE);
        raffle.enterRaffle{value: 1 ether}();
        (,uint256 lotteryInterval,,,,,) = helperConfig.activeConfig();
        vm.warp(block.timestamp + lotteryInterval);
        vm.roll(block.number + 1);

        raffle.performUpkeep("0x0");

        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        hoax(PLAYER, USER_BALANE);
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
        hoax(PLAYER, USER_BALANE);
        raffle.enterRaffle{value: 1 ether}();
        (,uint256 lotteryInterval,,,,,) = helperConfig.activeConfig();
        vm.warp(block.timestamp + lotteryInterval);
        vm.roll(block.number + 1);
        (bool isUpkeepNeeded,) = raffle.checkUpkeep("0x0");
        assertTrue(isUpkeepNeeded);
    }
}
