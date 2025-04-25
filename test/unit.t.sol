// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TicketDoge} from "../src/TicketDoge.sol";
import {USDT} from "./mocks/USDT.sol";

contract CounterTest is Test {
    TicketDoge ticket;
    USDT usdt;
    address owner = address(100);
    address teamWallet = address(101);
    address futureWallet = address(102);
    address charityWallet = address(103);

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
        ticket = new TicketDoge(
            owner,
            address(usdt),
            14000000000000000000,
            teamWallet,
            futureWallet,
            charityWallet
        );
    }

    mapping(string => bool) strings;

    function testRandString() public {
        for (uint u = 0; u < 1000; u++) {
            vm.warp(block.timestamp + 100);
            // Create a new bytes array to hold 8 characters.
            bytes memory result = new bytes(8);

            // Create a "random" seed based on block data and the caller’s address.
            // Note: This is not secure for high-stakes randomness.
            uint256 randomSeed = uint256(
                keccak256(abi.encodePacked(block.timestamp, msg.sender))
            );

            // Generate 3 random letters (A-Z)
            for (uint256 i = 0; i < 3; i++) {
                // Update the random seed for each letter
                uint256 rand = uint256(
                    keccak256(abi.encodePacked(randomSeed, i))
                );
                // Map the random number to a letter between 0 and 25, then add 65 for ASCII 'A'
                result[i] = bytes1(uint8(65 + (rand % 26)));
            }

            // Insert the dash at position 3
            result[3] = bytes1(uint8(45)); // ASCII code for '-' is 45

            // Generate 4 random digits (0-9)
            for (uint256 i = 4; i < 8; i++) {
                // Update the random seed for each digit (offset the index to avoid clashing with letters)
                uint256 rand = uint256(
                    keccak256(abi.encodePacked(randomSeed, i))
                );
                // Map the random number to a digit between 0 and 9, then add 48 for ASCII '0'
                result[i] = bytes1(uint8(48 + (rand % 10)));
            }

            vm.assertFalse(strings[string(result)]);
            strings[string(result)] = true;
        }
    }

    function createNft(address user) public {
        vm.prank(owner);
        usdt.transfer(user, MINIMUM_ENTRANCE);

        vm.startPrank(user);
        usdt.approve(address(ticket), type(uint256).max);
        ticket.createNft(MINIMUM_ENTRANCE, user, false, "", "");
        vm.stopPrank();
    }

    function createNft(address user, uint256 amount) public {
        vm.prank(owner);
        usdt.transfer(user, amount);

        vm.startPrank(user);
        usdt.approve(address(ticket), type(uint256).max);
        ticket.createNft(amount, user, false, "", "");
        vm.stopPrank();
    }

    function createNft(address user, string memory upline) public {
        vm.prank(owner);
        usdt.transfer(user, MINIMUM_ENTRANCE);

        vm.startPrank(user);
        usdt.approve(address(ticket), type(uint256).max);
        ticket.createNft(MINIMUM_ENTRANCE, user, true, upline, "");
        vm.stopPrank();
    }

    function createNft(
        address user,
        uint256 amount,
        string memory upline
    ) public {
        vm.prank(owner);
        usdt.transfer(user, amount);

        vm.startPrank(user);
        usdt.approve(address(ticket), type(uint256).max);
        ticket.createNft(amount, user, true, upline, "");
        vm.stopPrank();
    }

    function testCreateNft() public {
        createNft(user1);
        vm.assertEq(ticket.balanceOf(user1), 1);
        vm.assertEq(usdt.balanceOf(user1), 0);
        vm.assertEq(usdt.balanceOf(teamWallet), (MINIMUM_ENTRANCE * 21) / 100);
        vm.assertEq(
            usdt.balanceOf(futureWallet),
            (MINIMUM_ENTRANCE * 21) / 100
        );
        vm.assertEq(
            usdt.balanceOf(charityWallet),
            (MINIMUM_ENTRANCE * 8) / 100
        );

        vm.prank(user1);
        TicketDoge.ListedToken memory token = ticket.getMyNFTs()[0];

        vm.assertEq(token.tokenURI, "");
        vm.assertEq(token.drawId, 1);
        vm.assertEq(token.owner, user1);
        vm.assertEq(token.price, MINIMUM_ENTRANCE);
        vm.assertEq(token.uplineId, 0);
        vm.assertEq(token.totalreferralUsed, 0);
        vm.assertEq(token.totalReferralEarned, 0);
    }

    function testRevertsOnNotReferral() public {
        vm.prank(owner);
        usdt.transfer(user1, MINIMUM_ENTRANCE);

        vm.startPrank(user1);
        usdt.approve(address(ticket), type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(
                TicketDoge.TicketDoge__Error.selector,
                "Referral Does Not Exist"
            )
        );
        ticket.createNft(MINIMUM_ENTRANCE, user1, true, "", "");
    }

    function testRevertsOnNotEnoughAmountToSend() public {
        vm.prank(owner);
        usdt.transfer(user1, 10000000000000000000);

        vm.startPrank(user1);
        usdt.approve(address(ticket), type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(
                TicketDoge.TicketDoge__Error.selector,
                "Insufficient Amount To Send"
            )
        );
        ticket.createNft(10000000000000000000, user1, false, "", "");
    }

    function testRevertsOnSelfReferral() public {
        vm.prank(owner);
        usdt.transfer(user1, MINIMUM_ENTRANCE * 2);

        vm.startPrank(user1);
        usdt.approve(address(ticket), type(uint256).max);

        ticket.createNft(MINIMUM_ENTRANCE, user1, false, "", "");

        string memory referral = ticket.tokenIdToReferral(1);

        vm.expectRevert(
            abi.encodeWithSelector(
                TicketDoge.TicketDoge__Error.selector,
                "Can not Use Your Own Referral"
            )
        );
        ticket.createNft(MINIMUM_ENTRANCE, user1, true, referral, "");
        vm.stopPrank();
    }

    function testUseReferral() public {
        createNft(user1);
        vm.assertEq(usdt.balanceOf(user1), 0);
        uint256 amount = 20000000000000000000;
        createNft(user2, amount, ticket.tokenIdToReferral(1));
        vm.assertEq(usdt.balanceOf(user1), (amount * 90 * 21) / 10000);
        vm.assertEq(usdt.balanceOf(user2), (amount * 10) / 100);

        TicketDoge.ListedToken memory token1 = ticket.getToken(1);
        vm.assertEq(token1.totalreferralUsed, 1);
        vm.assertEq(token1.totalReferralEarned, (amount * 90 * 21) / 10000);

        TicketDoge.ListedToken memory token2 = ticket.getToken(2);
        vm.assertEq(token2.uplineId, 1);
    }

    function testSelectWinner() public {
        createNft(user1);
        createNft(user2, 20000000000000000000);
        createNft(user3, 30000000000000000000);
        createNft(user4);
        createNft(user5, 35000000000000000000);
        createNft(user6, 17000000000000000000);
        createNft(user7);
        createNft(user8, 30000000000000000000);
        createNft(user9, 25000000000000000000);
        createNft(user10, 27000000000000000000);
        vm.expectRevert(
            abi.encodeWithSelector(
                TicketDoge.TicketDoge__Error.selector,
                "Target Pool Balance Is Not Reached"
            )
        );
        ticket.selectingWinners();
        createNft(user11, 35000000000000000000);
        createNft(user12, 35000000000000000000);
        createNft(user13, 35000000000000000000);
        createNft(user14, 35000000000000000000);
        createNft(user15, 35000000000000000000);
        createNft(user16, 35000000000000000000);
        createNft(user17, 35000000000000000000);
        createNft(user18, 35000000000000000000);

        vm.prank(owner);
        usdt.transfer(user19, MINIMUM_ENTRANCE);

        vm.startPrank(user19);
        usdt.approve(address(ticket), type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(
                TicketDoge.TicketDoge__Error.selector,
                "Target Pool Balance Is Reached, Wait For Selecting Winner"
            )
        );
        ticket.createNft(MINIMUM_ENTRANCE, user19, false, "", "");
        vm.stopPrank();

        uint256 drawPoolBefor = ticket.drawPool();

        ticket.selectingWinners();

        address newWinner = ticket.getLatestNewPlayersWinner();
        uint256 newWinnerPrize = ticket.getLatestNewPlayersPrize();

        address oldWinner = ticket.getLatestOldPlayersWinner();
        uint256 oldWinnerPrize = ticket.getLatestOldPlayersPrize();

        vm.assertEq(usdt.balanceOf(newWinner), newWinnerPrize);
        vm.assertEq(usdt.balanceOf(oldWinner), oldWinnerPrize);

        vm.assertEq(
            drawPoolBefor - ticket.drawPool(),
            newWinnerPrize + oldWinnerPrize
        );

        createNft(user19);
    }
}
