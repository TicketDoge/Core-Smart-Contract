// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {TicketDoge} from "../../src/TicketDoge.sol";
import {USDT} from "../mocks/USDT.sol";
import {Doge} from "../mocks/Doge.sol";
import {MockV3Aggregator} from "../mocks/MockAggregator.sol";

contract CounterTest is Test {
    TicketDoge ticket;
    USDT usdt;
    Doge doge;
    MockV3Aggregator feed;

    address owner = address(100);
    address teamWallet = address(101);
    address futureWallet = address(102);
    address charityWallet = address(103);
    address dogeHolder = address(104);

    address user1 = address(1);
    address user2 = address(2);
    address user3 = address(3);
    address user4 = address(4);
    address user5 = address(5);
    address user6 = address(6);
    address user7 = address(7);
    address user8 = address(8);
    address user9 = address(9);
    address user10 = address(10);
    address user11 = address(11);
    address user12 = address(12);
    address user13 = address(13);
    address user14 = address(14);
    address user15 = address(15);
    address user16 = address(16);
    address user17 = address(17);
    address user18 = address(18);
    address user19 = address(19);
    address user20 = address(20);
    address user21 = address(21);
    address user22 = address(22);
    address user23 = address(23);

    uint256 MINIMUM_ENTRANCE = 15000000000000000000;

    function setUp() public {
        vm.prank(owner);
        usdt = new USDT();
        vm.prank(dogeHolder);
        doge = new Doge();

        feed = new MockV3Aggregator(10, 1e9);

        ticket = new TicketDoge(
            owner,
            address(usdt),
            address(doge),
            14000000000000000000,
            teamWallet,
            futureWallet,
            charityWallet,
            dogeHolder,
            address(feed)
        );

        vm.prank(dogeHolder);
        doge.approve(address(ticket), 1e40);
    }

    function mintTicket(address user) public {
        vm.prank(owner);
        usdt.transfer(user, MINIMUM_ENTRANCE);

        vm.startPrank(user);
        usdt.approve(address(ticket), type(uint256).max);
        ticket.mintTicket(MINIMUM_ENTRANCE, user, false, "", "");
        vm.stopPrank();
    }

    function mintTicket(address user, uint256 amount) public {
        vm.prank(owner);
        usdt.transfer(user, amount);

        vm.startPrank(user);
        usdt.approve(address(ticket), type(uint256).max);
        ticket.mintTicket(amount, user, false, "", "");
        vm.stopPrank();
    }

    function mintTicket(address user, string memory upline) public {
        vm.prank(owner);
        usdt.transfer(user, MINIMUM_ENTRANCE);

        vm.startPrank(user);
        usdt.approve(address(ticket), type(uint256).max);
        ticket.mintTicket(MINIMUM_ENTRANCE, user, true, upline, "");
        vm.stopPrank();
    }

    function mintTicket(address user, uint256 amount, string memory upline) public {
        vm.prank(owner);
        usdt.transfer(user, amount);

        vm.startPrank(user);
        usdt.approve(address(ticket), type(uint256).max);
        ticket.mintTicket(amount, user, true, upline, "");
        vm.stopPrank();
    }

    function testCreateNft() public {
        mintTicket(user1);
        vm.assertEq(ticket.balanceOf(user1), 1);
        vm.assertEq(usdt.balanceOf(user1), 0);
        vm.assertEq(usdt.balanceOf(teamWallet), (MINIMUM_ENTRANCE * 21) / 100);
        vm.assertEq(usdt.balanceOf(futureWallet), (MINIMUM_ENTRANCE * 21) / 100);
        vm.assertEq(usdt.balanceOf(charityWallet), (MINIMUM_ENTRANCE * 8) / 100);

        vm.prank(user1);
        TicketDoge.Ticket memory token = ticket.myTickets()[0];

        vm.assertEq(token.uri, "");
        vm.assertEq(token.holder, user1);
        vm.assertEq(token.price, MINIMUM_ENTRANCE);
        vm.assertEq(token.referrerId, 0);
        vm.assertEq(token.timesUsed, 0);
        vm.assertEq(token.earnings, 0);
    }

    function testRevertsOnNotReferral() public {
        vm.prank(owner);
        usdt.transfer(user1, MINIMUM_ENTRANCE);

        vm.startPrank(user1);
        usdt.approve(address(ticket), type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(TicketDoge.TDError.selector, "Invalid referral code"));
        ticket.mintTicket(MINIMUM_ENTRANCE, user1, true, "", "");
    }

    function testRevertsOnNotEnoughAmountToSend() public {
        vm.prank(owner);
        usdt.transfer(user1, 10000000000000000000);

        vm.startPrank(user1);
        usdt.approve(address(ticket), type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(TicketDoge.TDError.selector, "Below minimum entry"));
        ticket.mintTicket(10000000000000000000, user1, false, "", "");
    }

    function testRevertsOnSelfReferral() public {
        vm.prank(owner);
        usdt.transfer(user1, MINIMUM_ENTRANCE * 2);

        vm.startPrank(user1);
        usdt.approve(address(ticket), type(uint256).max);

        ticket.mintTicket(MINIMUM_ENTRANCE, user1, false, "", "");

        string memory referral = ticket.ticketToReferral(1);

        vm.expectRevert(abi.encodeWithSelector(TicketDoge.TDError.selector, "Can not Use Your Own Referral"));
        ticket.mintTicket(MINIMUM_ENTRANCE, user1, true, referral, "");
        vm.stopPrank();
    }

    function testUseReferral() public {
        mintTicket(user1);
        vm.assertEq(usdt.balanceOf(user1), 0);

        uint256 usdtBalanceBefore = usdt.balanceOf(dogeHolder);
        uint256 dogeBalanceBefore = doge.balanceOf(dogeHolder);
        uint256 amount = 20e18;
        mintTicket(user2, amount, ticket.ticketToReferral(1));
        uint256 usdtBalanceAfter = usdt.balanceOf(dogeHolder);
        uint256 dogeBalanceAfter = doge.balanceOf(dogeHolder);
        uint256 usdtEquivalent = (amount * 90 * 21) / 10000;
        uint256 dogeEquivalent = usdtEquivalent * 1e10 / 1e9;
        uint256 dogeAmount = dogeEquivalent / 1e10;
        vm.assertEq(usdtBalanceAfter - usdtBalanceBefore, usdtEquivalent);
        vm.assertEq(dogeBalanceBefore - dogeBalanceAfter, dogeAmount);
        vm.assertEq(doge.balanceOf(user1), dogeAmount);
        vm.assertEq(doge.balanceOf(user1), 378e7);
        vm.assertEq(usdt.balanceOf(user2), (amount * 10) / 100);
        TicketDoge.Ticket memory token1 = ticket.getTicket(1);
        vm.assertEq(token1.timesUsed, 1);
        vm.assertEq(token1.earnings, (amount * 90 * 21) / 10000);
        TicketDoge.Ticket memory token2 = ticket.getTicket(2);
        vm.assertEq(token2.referrerId, 1);

        feed.updateAnswer(2e9);

        mintTicket(user3, amount, ticket.ticketToReferral(2));
        vm.assertEq(doge.balanceOf(user2), dogeAmount / 2);
        vm.assertEq(doge.balanceOf(user2), 378e7 / 2);
    }

    function testSelectWinner() public {
        mintTicket(user1);
        mintTicket(user2, 20000000000000000000);
        mintTicket(user3, 30000000000000000000);
        mintTicket(user4);
        mintTicket(user5, 35000000000000000000);
        mintTicket(user6, 17000000000000000000);
        mintTicket(user7);
        mintTicket(user8, 30000000000000000000);
        mintTicket(user9, 25000000000000000000);
        mintTicket(user10, 27000000000000000000);
        ticket.pickWinners();

        // vm.prank(owner);
        // usdt.transfer(user19, MINIMUM_ENTRANCE);

        // vm.startPrank(user19);
        // usdt.approve(address(ticket), type(uint256).max);
        // vm.expectRevert(abi.encodeWithSelector(TicketDoge.TDError.selector, "Draw not open"));
        // ticket.mintTicket(MINIMUM_ENTRANCE, user19, false, "", "");
        // vm.stopPrank();

        // uint256 drawPoolBefor = ticket.drawPool();

        // ticket.pickWinners();

        // address newWinner = ticket.latestNewWinner();
        // uint256 newWinnerPrize = ticket.latestNewPrize();

        // address oldWinner = ticket.latestOldWinner();
        // uint256 oldWinnerPrize = ticket.latestOldPrize();

        // vm.assertEq(usdt.balanceOf(newWinner), newWinnerPrize);
        // vm.assertEq(usdt.balanceOf(oldWinner), oldWinnerPrize);

        // vm.assertEq(drawPoolBefor - ticket.drawPool(), newWinnerPrize + oldWinnerPrize);

        // mintTicket(user19);
    }

    mapping(string => bool) strings;

    function testRandString() public {
        for (uint256 u = 0; u < 1000; u++) {
            vm.warp(block.timestamp + 100);
            // Create a new bytes array to hold 8 characters.
            bytes memory result = new bytes(8);

            // Create a "random" seed based on block data and the caller’s address.
            // Note: This is not secure for high-stakes randomness.
            uint256 randomSeed = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender)));

            // Generate 3 random letters (A-Z)
            for (uint256 i = 0; i < 3; i++) {
                // Update the random seed for each letter
                uint256 rand = uint256(keccak256(abi.encodePacked(randomSeed, i)));
                // Map the random number to a letter between 0 and 25, then add 65 for ASCII 'A'
                result[i] = bytes1(uint8(65 + (rand % 26)));
            }

            // Insert the dash at position 3
            result[3] = bytes1(uint8(45)); // ASCII code for '-' is 45

            // Generate 4 random digits (0-9)
            for (uint256 i = 4; i < 8; i++) {
                // Update the random seed for each digit (offset the index to avoid clashing with letters)
                uint256 rand = uint256(keccak256(abi.encodePacked(randomSeed, i)));
                // Map the random number to a digit between 0 and 9, then add 48 for ASCII '0'
                result[i] = bytes1(uint8(48 + (rand % 10)));
            }

            vm.assertFalse(strings[string(result)]);
            strings[string(result)] = true;
        }
    }

    function testXioms() public {
        mintTicket(user1);
        uint256 initXiom1 = ticket.xiomOf(1);
        string memory upline1 = ticket.ticketToReferral(1);
        mintTicket(user2, upline1);
        uint256 initXiom2 = ticket.xiomOf(2);
        string memory upline2 = ticket.ticketToReferral(2);
        mintTicket(user3, upline2);
        uint256 initXiom3 = ticket.xiomOf(3);
        string memory upline3 = ticket.ticketToReferral(3);
        mintTicket(user4, upline3);
        uint256 initXiom4 = ticket.xiomOf(4);

        mintTicket(user5, upline2);

        vm.assertEq(ticket.xiomOf(1), initXiom1 + 6000);
        vm.assertEq(ticket.xiomOf(2), initXiom2 + 4500);
        vm.assertEq(ticket.xiomOf(3), initXiom3 + 1500);
        vm.assertEq(ticket.xiomOf(4), initXiom4 + 0);
    }
}
