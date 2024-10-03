// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {TeslaNFT} from "../../../src/TeslaNft.sol";
import {DogeCoin} from "../../../src/Token.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Handler} from "./Handler.sol";
import {console} from "forge-std/console.sol";

contract InvariantWithoutReferral is StdInvariant, Test {
    Handler handler;
    TeslaNFT tesla;
    DogeCoin dogeCoin;
    address team = address(1);
    address futureProject = address(2);
    address charity = address(3);
    uint256 feePool = 50;
    uint256 feeTeam = 21;
    uint256 feeFutureProject = 21;
    uint256 feeCharity = 8;
    uint256 feeOwnerReferral = 21;
    uint256 feeSpenderReferral = 10;
    uint256 totalDogeWinner = 1e23;

    uint256 currentBetId = 1;
    uint256 currentPool;

    function setUp() public {
        dogeCoin = new DogeCoin();
        tesla = new TeslaNFT(
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
        handler = new Handler(
            team,
            futureProject,
            charity,
            feePool,
            feeTeam,
            feeFutureProject,
            feeCharity,
            feeOwnerReferral,
            feeSpenderReferral,
            totalDogeWinner,
            tesla,
            dogeCoin
        );

        dogeCoin.transfer(address(handler), dogeCoin.balanceOf(address(this)));
        targetContract(address(handler));
    }

    function invariant_withReferralTransfersRewardsToOwners() public view {
        uint256 tolerance = 5; // Define tolerance value

        address referralOwner = handler.getReferralOwner();
        if (tesla.getRecentTotalWinner() == referralOwner) {
            return;
        }
        if (tesla.getRecentNewWinner() == referralOwner) {
            return;
        }

        // Get the expected balances after a transaction in the handler
        uint256 expectedTeamBalance = handler.expectedTeamBalance();
        uint256 actualTeamBalance = handler.dogeCoin().balanceOf(team);

        uint256 expectedFutureProjectBalance = handler
            .expectedFutureProjectBalance();
        uint256 actualFutureProjectBalance = handler.dogeCoin().balanceOf(
            futureProject
        );

        uint256 expectedCharityBalance = handler.expectedCharityBalance();
        uint256 actualCharityBalance = handler.dogeCoin().balanceOf(charity);

        uint256 expectedReferralOwnerBalance = handler
            .getExpectedReferralOwnerBalance();
        uint256 actualReferralOwnerBalance = handler.dogeCoin().balanceOf(
            referralOwner
        );

        // Check if the balances are within the tolerance range
        assertWithinTolerance(
            expectedTeamBalance,
            actualTeamBalance,
            tolerance
        );
        assertWithinTolerance(
            expectedFutureProjectBalance,
            actualFutureProjectBalance,
            tolerance
        );
        assertWithinTolerance(
            expectedCharityBalance,
            actualCharityBalance,
            tolerance
        );

        assertWithinTolerance(
            expectedReferralOwnerBalance,
            actualReferralOwnerBalance,
            tolerance
        );
    }

    function invariant_withReferralChoosesWinnerAndTransfersReward()
        public
        view
    {
        bool isFinedWinnerTransaction = handler.getIsFinedWinnerTransaction();
        if (isFinedWinnerTransaction) {
            uint256 totalPool = tesla.getTotalPool();
            address recentNewWinner = tesla.getRecentNewWinner();
            uint256 lastNewReward = tesla.getLastNewReward();
            uint256 actuallNewWinnerBalance = dogeCoin.balanceOf(
                recentNewWinner
            );

            address recentTotalWinner = tesla.getRecentTotalWinner();
            uint256 lastTotalReward = tesla.getLastTotalReward();
            uint256 actuallTotalWinnerBalance = dogeCoin.balanceOf(
                recentTotalWinner
            );

            vm.assertEq(totalPool, 0);

            if (recentNewWinner == recentTotalWinner) {
                assertGtWithinTolerance(
                    actuallNewWinnerBalance,
                    lastNewReward + lastTotalReward,
                    5
                );
            } else {
                assertGtWithinTolerance(
                    actuallNewWinnerBalance,
                    lastNewReward,
                    5
                );
                assertGtWithinTolerance(
                    actuallTotalWinnerBalance,
                    lastTotalReward,
                    5
                );
            }
        }
    }

    // Helper function to check values within tolerance
    function assertWithinTolerance(
        uint256 expected,
        uint256 actual,
        uint256 tolerance
    ) internal pure {
        if (expected > actual) {
            assert(expected - actual <= tolerance);
        } else {
            assert(actual - expected <= tolerance);
        }
    }

    function assertGtWithinTolerance(
        uint256 greatter,
        uint256 lesser,
        uint256 tolerance
    ) internal pure {
        assert(greatter >= lesser - tolerance);
    }
}
