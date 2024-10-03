// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {TeslaNFT} from "../../../src/TeslaNft.sol";
import {DogeCoin} from "../../../src/Token.sol";
import {console} from "forge-std/console.sol";

contract Handler is Test {
    DogeCoin public dogeCoin; // Make dogeCoin public so it can be accessed from Invariant
    TeslaNFT public tesla;
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
        TeslaNFT _tesla,
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
        tesla = _tesla;
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
                user != address(tesla) &&
                user != address(dogeCoin)
        );
        if (tesla.getReferralOwner(upReferral) != address(0)) {
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

        uint256 betIdBefore = tesla.getBetId();

        uint256 nftToCarPercentage = tesla.getNftToCarPercentage();
        uint256 betFeePercentage = tesla.getBetFeePercentage();

        uint256 transferAmount = (((totalPrice * nftToCarPercentage) *
            (10000 + betFeePercentage)) / 1e8);
        dogeCoin.transfer(user, transferAmount);
        vm.startPrank(user);
        dogeCoin.approve(address(tesla), transferAmount);
        tesla.createToken(
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

        uint256 betIdAfter = tesla.getBetId();
        if (betIdBefore != betIdAfter) {
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
