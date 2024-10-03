// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {TicketDoge} from "../../src/TicketDoge.sol";
import {DogeCoin} from "../../src/Token.sol";

contract TicketDogeFuzzTest is Test {
    DogeCoin dogeCoin = new DogeCoin();
    TicketDoge ticket;
    address team = address(1);
    address futureProject = address(2);
    address charity = address(3);
    uint256 feePool = 50;
    uint256 feeTeam = 21;
    uint256 feeFutureProject = 21;
    uint256 feeCharity = 8;
    uint256 feeOwnerReferral = 21;
    uint256 feeSpenderReferral = 10;
    uint256 totalDogeWinner = 1e21;

    function setUp() public {
        ticket = new TicketDoge(
            address(dogeCoin),
            team,
            futureProject,
            charity,
            feePool,
            feeTeam,
            feeFutureProject,
            feeCharity,
            feeOwnerReferral,
            feeSpenderReferral,
            totalDogeWinner
        );
    }

    function testFuzzTransfersToOwners(
        address user,
        string memory tokenURI,
        uint256 totalPrice,
        string memory referralCode,
        string memory upReferral,
        uint256 totalCarPrice
    ) public {
        if (totalPrice > 1e30 || totalPrice < 4e23) {
            return;
        }
        if (
            user == address(0) ||
            user == address(this) ||
            user == address(ticket) ||
            user == address(dogeCoin) ||
            user == address(vm)
        ) {
            return;
        }

        uint256 nftToCarPercentage = ticket.getNftToCarPercentage();
        uint256 drawFeePercentage = ticket.getDrawFeePercentage();

        uint256 transferAmount = (((totalPrice * nftToCarPercentage) *
            (10000 + drawFeePercentage)) / 1e8);
        dogeCoin.transfer(user, transferAmount);
        vm.startPrank(user);
        dogeCoin.approve(address(ticket), transferAmount);
        ticket.createToken(
            tokenURI,
            totalPrice,
            referralCode,
            upReferral,
            totalCarPrice
        );
        vm.stopPrank();

        vm.assertEq(dogeCoin.balanceOf(team), (transferAmount * 21) / 100);
        vm.assertEq(
            dogeCoin.balanceOf(futureProject),
            (transferAmount * 21) / 100
        );
        vm.assertEq(dogeCoin.balanceOf(charity), (transferAmount * 8) / 100);
    }

    function testFuzzTransfersToReferralOwner(
        address user,
        string memory tokenURI,
        uint256 totalPrice,
        string memory referralCode,
        string memory upReferral,
        uint256 totalCarPrice
    ) public {
        if (totalPrice > 1e30 || totalPrice < 4e23) {
            return;
        }

        if (
            user == address(0) ||
            user == address(this) ||
            user == address(ticket) ||
            user == address(dogeCoin) ||
            user == address(vm)
        ) {
            return;
        }

        uint256 nftToCarPercentage = ticket.getNftToCarPercentage();
        uint256 drawFeePercentage = ticket.getDrawFeePercentage();

        uint256 transferAmount = (((totalPrice * nftToCarPercentage) *
            (10000 + drawFeePercentage)) / 1e8);
        dogeCoin.transfer(user, transferAmount);
        vm.startPrank(user);
        dogeCoin.approve(address(ticket), transferAmount);
        ticket.createToken(
            tokenURI,
            totalPrice,
            referralCode,
            upReferral,
            totalCarPrice
        );
        vm.stopPrank();

        vm.assertEq(dogeCoin.balanceOf(team), (transferAmount * 21) / 100);
        vm.assertEq(
            dogeCoin.balanceOf(futureProject),
            (transferAmount * 21) / 100
        );
        vm.assertEq(dogeCoin.balanceOf(charity), (transferAmount * 8) / 100);
    }
}
