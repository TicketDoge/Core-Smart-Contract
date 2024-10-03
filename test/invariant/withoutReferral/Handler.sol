// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {TicketDoge} from "../../../src/TicketDoge.sol";
import {DogeCoin} from "../../../src/Token.sol";
import {console} from "forge-std/console.sol";

contract Handler is Test {
    DogeCoin public dogeCoin; // Make dogeCoin public so it can be accessed from Invariant
    TicketDoge public ticket;
    address public team;
    address public futureProject;
    address public charity;
    uint256 public feePool;
    uint256 public feeTeam;
    uint256 public feeFutureProject;
    uint256 public feeCharity;
    uint256 public feeOwnerReferral;
    uint256 public feeSpenderReferral;
    uint256 public totalDogeWinner;

    uint256 public expectedTeamBalance;
    uint256 public expectedFutureProjectBalance;
    uint256 public expectedCharityBalance;

    bool isFinedWinnerTransaction;

    constructor(
        address _team,
        address _futureProject,
        address _charity,
        uint256 _feePool,
        uint256 _feeTeam,
        uint256 _feeFutureProject,
        uint256 _feeCharity,
        uint256 _feeOwnerReferral,
        uint256 _feeSpenderReferral,
        uint256 _totalDogeWinner,
        TicketDoge _ticket,
        DogeCoin _dogeCoin
    ) {
        team = _team;
        futureProject = _futureProject;
        charity = _charity;
        feePool = _feePool;
        feeTeam = _feeTeam;
        feeFutureProject = _feeFutureProject;
        feeCharity = _feeCharity;
        feeOwnerReferral = _feeOwnerReferral;
        feeSpenderReferral = _feeSpenderReferral;
        totalDogeWinner = _totalDogeWinner;
        ticket = _ticket;
        dogeCoin = _dogeCoin;
    }

    function transfersToOwners(
        address user,
        string memory tokenURI,
        uint256 totalPrice,
        string memory referralCode,
        string memory upReferral,
        uint256 totalCarPrice
    ) public {
        vm.assume(totalPrice >= 4e23 && totalPrice <= 1e30);

        vm.assume(
            user != address(0) &&
                user != address(this) &&
                user != address(ticket) &&
                user != address(dogeCoin)
        );
        if (ticket.getReferralOwner(upReferral) != address(0)) {
            return;
        }

        if (
            user == team ||
            user == futureProject ||
            user == charity ||
            user == address(vm)
        ) {
            return;
        }

        uint256 balanceBeforeTeam = dogeCoin.balanceOf(team);
        uint256 balanceBeforeFutureProject = dogeCoin.balanceOf(futureProject);
        uint256 balanceBeforeCharity = dogeCoin.balanceOf(charity);

        uint256 drawIdBefore = ticket.getDrawId();

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

        // Calculate expected balances after the transfers
        expectedTeamBalance = balanceBeforeTeam + (transferAmount * 21) / 100;
        expectedFutureProjectBalance =
            balanceBeforeFutureProject +
            (transferAmount * 21) /
            100;
        expectedCharityBalance =
            balanceBeforeCharity +
            (transferAmount * 8) /
            100;

        uint256 drawIdAfter = ticket.getDrawId();
        if (drawIdBefore != drawIdAfter) {
            isFinedWinnerTransaction = true;
        } else {
            isFinedWinnerTransaction = false;
        }
    }

    // Getter functions to expose expected balances
    function getExpectedTeamBalance() public view returns (uint256) {
        return expectedTeamBalance;
    }

    function getExpectedFutureProjectBalance() public view returns (uint256) {
        return expectedFutureProjectBalance;
    }

    function getExpectedCharityBalance() public view returns (uint256) {
        return expectedCharityBalance;
    }

    function getIsFinedWinnerTransaction() public view returns (bool) {
        return isFinedWinnerTransaction;
    }
}
