// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {TicketDoge} from "../../../src/TicketDoge.sol";
import {USDT} from "../../mocks/USDT.sol";
import {Doge} from "../../mocks/Doge.sol";
import {Test} from "forge-std/Test.sol";
import {MockV3Aggregator} from "../../mocks/MockAggregator.sol";

contract Handler is Test {
    TicketDoge ticket;
    USDT usdt;
    Doge doge;
    MockV3Aggregator feed;
    address owner = address(100);
    address teamWallet = address(101);
    address futureWallet = address(102);
    address charityWallet = address(103);
    address dogeHolder = address(104);

    constructor() {
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

    function mintTicket(address user, uint256 amount) public {
        if (ticket.currentState() == TicketDoge.LotteryState.Drawing) {
            ticket.pickWinners();
        }

        vm.assume(
            user != address(0) && user != teamWallet && user != futureWallet && user != charityWallet
                && user != address(this) && user != owner && user != address(ticket) && user != address(usdt)
                && user != address(vm) && user != 0x4e59b44847b379578588920cA78FbF26c0B4956C
        );

        amount = bound(amount, ticket.minEntry(), ticket.maxEntry());
        vm.prank(owner);
        usdt.transfer(user, amount);

        vm.startPrank(user);
        usdt.approve(address(ticket), type(uint256).max);
        ticket.mintTicket(amount, user, false, "", "");
        vm.stopPrank();
    }
}
