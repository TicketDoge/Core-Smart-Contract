// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TicketDoge, ListedToken} from "../../src/TicketDoge.sol";
import {DogeCoin} from "../../src/Token.sol";

contract testTicketDoge is Test {
    TicketDoge ticket;
    DogeCoin dogeCoin;

    address team = address(1);
    address futureProject = address(2);
    address charity = address(3);
    address user1 = address(4);
    address user2 = address(5);
    address user3 = address(6);
    address user4 = address(7);
    address user5 = address(8);
    address user6 = address(9);

    uint256 constant FEE_POOL = 50;
    uint256 constant FEE_TEAM = 21;
    uint256 constant FEE_FUTURE_PROJECT = 21;
    uint256 constant FEE_CHARITY = 8;
    uint256 constant FEE_SPENDER_REFERRAL = 10;
    uint256 constant FEE_OWNER_REFERRAL = 21;
    uint256 constant TOTAL_DOGE_WINNER = 10e20;

    uint256 constant ENTRY_AMOUNT = 8e23;

    function setUp() public {
        dogeCoin = new DogeCoin();
        ticket = new TicketDoge(
            address(dogeCoin),
            team,
            futureProject,
            charity,
            FEE_POOL,
            FEE_TEAM,
            FEE_FUTURE_PROJECT,
            FEE_CHARITY,
            FEE_OWNER_REFERRAL,
            FEE_SPENDER_REFERRAL,
            TOTAL_DOGE_WINNER
        );
    }

    function createNft(
        address user,
        string memory referralcode,
        string memory referralOld
    ) public {
        uint256 nftToCarPercentage = ticket.getNftToCarPercentage();
        uint256 drawFeePercentage = ticket.getDrawFeePercentage();
        dogeCoin.transfer(
            user,
            (((ENTRY_AMOUNT * nftToCarPercentage) *
                (10000 + drawFeePercentage)) / 1e8)
        );
        vm.startPrank(user);
        dogeCoin.approve(
            address(ticket),
            (((ENTRY_AMOUNT * nftToCarPercentage) *
                (10000 + drawFeePercentage)) / 1e8)
        );
        ticket.createToken(
            "kshfvbksnvklwnj",
            ENTRY_AMOUNT,
            referralcode,
            referralOld,
            ENTRY_AMOUNT
        );
        vm.stopPrank();
    }

    function testSendsWinningAmountToWinner() public {
        createNft(user1, "jdchjgyfh", "wlksgnkwsgnwklg");
        createNft(user2, "ksjbvskjbvf", "alejbfakjfn");
        createNft(user3, "akeufbhikf", "askefjbakjsf");
        address newWinner = ticket.getRecentNewWinner();
        address totalWinner = ticket.getRecentTotalWinner();
        if (newWinner == totalWinner) {
            vm.assertEq(dogeCoin.balanceOf(newWinner), 12000e17);
        } else {
            vm.assertEq(dogeCoin.balanceOf(newWinner), 6000e17);
            vm.assertEq(dogeCoin.balanceOf(totalWinner), 6000e17);
        }

        createNft(user4, "skejfbh", "skaefbuwksjefb");
        createNft(user5, "slefngsjk", "askejfb");
        createNft(user6, "aeskfhvbes", "amkbfskfj");
        address newWinner2 = ticket.getRecentNewWinner();
        address totalWinner2 = ticket.getRecentTotalWinner();
        if (newWinner2 == totalWinner2) {
            vm.assertEq(dogeCoin.balanceOf(newWinner2), 12132e17);
        } else {
            vm.assertEq(dogeCoin.balanceOf(newWinner2), 6066e17);
            vm.assertEq(dogeCoin.balanceOf(totalWinner2), 6066e17);
        }
    }

    function testIfTransfersAmountToReferralOwner() public {
        createNft(user1, "referral1", "wlksgnkwsgnw");
        vm.assertEq(dogeCoin.balanceOf(user1), 0);
        string memory referral = ticket.getReferralCodeById(1);
        dogeCoin.transfer(user2, (((ENTRY_AMOUNT * 10) / 10000) * 9) / 10);
        vm.startPrank(user2);
        dogeCoin.approve(
            address(ticket),
            (((ENTRY_AMOUNT * 10) / 10000) * 9) / 10
        );
        ticket.createToken("", ENTRY_AMOUNT, "jgtvujh", referral, ENTRY_AMOUNT);
        vm.stopPrank();
        uint256 tokenId = ticket.getTokenIdByReferral(referral);
        ListedToken memory token = ticket.getListedTokenFromId(tokenId);
        vm.assertEq(token.totalreferralUsed, 1);
        vm.assertEq(dogeCoin.balanceOf(user2), 0);
        vm.assertEq(dogeCoin.balanceOf(user1), 1512e17);
    }

    function testReferralOwnerChangesIfNftSales() public {
        createNft(user1, "referral1", "wlksgnkwsgnw");
        vm.prank(user1);
        ticket.transferFrom(user1, user2, 1);
        string memory referral = ticket.getReferralCodeById(1);

        createNft(user3, "referral2", referral);

        uint256 tokenId = ticket.getTokenIdByReferral(referral);
        ListedToken memory token = ticket.getListedTokenFromId(tokenId);
        vm.assertEq(token.totalreferralUsed, 1);
        vm.assertEq(dogeCoin.balanceOf(user1), 0);
        vm.assertEq(dogeCoin.balanceOf(user2), 1512e17);
    }

    function testTransfersAmountToOwnersOfContract() public {
        createNft(user1, "jdchjgyfh", "wlksgnkwsgnwklg");
        vm.assertEq(dogeCoin.balanceOf(team), 168e18);
        vm.assertEq(dogeCoin.balanceOf(futureProject), 168e18);
        vm.assertEq(dogeCoin.balanceOf(charity), 64e18);
    }

    function testReferralWorksFine() public {
        createNft(user1, "referral1", "wlksgnkwsgnw");

        string memory referral = ticket.getReferralCodeById(1);
        dogeCoin.transfer(user2, (((ENTRY_AMOUNT * 10) / 10000) * 9) / 10);
        vm.startPrank(user2);
        dogeCoin.approve(
            address(ticket),
            (((ENTRY_AMOUNT * 10) / 10000) * 9) / 10
        );
        ticket.createToken("", ENTRY_AMOUNT, "jgtvujh", referral, ENTRY_AMOUNT);
        vm.stopPrank();

        string memory referral2 = ticket.getReferralCodeById(2);
        dogeCoin.transfer(user3, (((ENTRY_AMOUNT * 10) / 10000) * 9) / 10);
        vm.startPrank(user3);
        dogeCoin.approve(
            address(ticket),
            (((ENTRY_AMOUNT * 10) / 10000) * 9) / 10
        );
        ticket.createToken(
            "",
            ENTRY_AMOUNT,
            "jgtvuikhbijh",
            referral2,
            ENTRY_AMOUNT
        );
        vm.stopPrank();

        string memory referral3 = ticket.getReferralCodeById(1);
        dogeCoin.transfer(user4, (((ENTRY_AMOUNT * 10) / 10000) * 9) / 10);
        vm.startPrank(user4);
        dogeCoin.approve(
            address(ticket),
            (((ENTRY_AMOUNT * 10) / 10000) * 9) / 10
        );
        ticket.createToken(
            "",
            ENTRY_AMOUNT,
            "jgtvuikhbsdfcijh",
            referral3,
            ENTRY_AMOUNT
        );
        vm.stopPrank();

        vm.assertEq(ticket.getAllDirects(1), 3);
        vm.assertEq(ticket.getAllDirects(2), 1);
        vm.assertEq(ticket.getAllDirects(3), 0);
    }

    function testFailsIfNotEnoughDogePrice() public {
        dogeCoin.transfer(address(1), (2e23));
        vm.startPrank(address(1));
        dogeCoin.approve(address(ticket), (2e23));
        vm.expectRevert(0xf4844814);
        ticket.createToken(
            "kshfvbksnvklwnj",
            2e23,
            "lksnvlkfns",
            "dlfbnj",
            2e23
        );
        vm.stopPrank();
    }

    function testRevertIfSomeOneUseHisOwnReferral() public {
        createNft(user1, "referral1", "wlksgnkwsgnw");
        vm.prank(user1);
        string memory referral = ticket.getReferralCodeById(1);
        address owner = ticket.getReferralOwner(referral);
        vm.assertEq(owner, user1);

        uint256 nftToCarPercentage = ticket.getNftToCarPercentage();
        uint256 drawFeePercentage = ticket.getDrawFeePercentage();
        dogeCoin.transfer(
            user1,
            (((ENTRY_AMOUNT * nftToCarPercentage) *
                (10000 + drawFeePercentage)) / 1e8)
        );
        vm.startPrank(user1);
        dogeCoin.approve(
            address(ticket),
            (((ENTRY_AMOUNT * nftToCarPercentage) *
                (10000 + drawFeePercentage)) / 1e8)
        );

        vm.expectRevert();
        ticket.createToken(
            "kshfvbksnvklwnj",
            ENTRY_AMOUNT,
            "referral2",
            referral,
            ENTRY_AMOUNT
        );
        vm.stopPrank();
    }

    function testFailsIfReferralAlreadyCreated() public {
        createNft(user1, "referral", "lrjnfnwr");
        vm.expectRevert();
        createNft(user2, "referral", "wolfnwfk");
    }
}
