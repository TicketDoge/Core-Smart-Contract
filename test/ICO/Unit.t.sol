// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {Aquatimus} from "../../src/ICO/MKFS.sol";
import {AquatimusICO} from "../../src/ICO/ICO.sol";
import {USDT} from "../mocks/USDT.sol";

contract ICOTest is Test {
    Aquatimus mkfs;
    AquatimusICO ico;
    USDT usdt;

    address owner = address(100);
    address user1 = address(1);
    address user2 = address(1);
    address user3 = address(1);
    address user4 = address(1);

    function setUp() public {
        mkfs = new Aquatimus(owner, address(10000));
        vm.startPrank(owner);
        usdt = new USDT();
        ico = new AquatimusICO(owner, address(mkfs), address(usdt));
        mkfs.transfer(address(ico), 3_000_000_000_000e18);
        vm.stopPrank();
    }

    function fundUsdt(address user, uint256 amount) public {
        vm.prank(owner);
        usdt.transfer(user, amount);
        vm.prank(user);
        usdt.approve(address(ico), type(uint256).max);
    }

    function testBuy() public {
        fundUsdt(user1, 1000e18);

        uint256 usdtBalanceBefore = usdt.balanceOf(user1);
        uint256 mkfsBalanceBefore = mkfs.balanceOf(user1);
        uint256 usdtBalanceBeforeOwner = usdt.balanceOf(owner);

        vm.prank(user1);
        ico.buy(user1, 1000e18);

        uint256 usdtBalanceAfter = usdt.balanceOf(user1);
        uint256 mkfsBalanceAfter = mkfs.balanceOf(user1);
        uint256 usdtBalanceAfterOwner = usdt.balanceOf(owner);

        assertEq(usdtBalanceBefore - usdtBalanceAfter, 1000e18 * 24 / 10000);
        assertEq(mkfsBalanceAfter - mkfsBalanceBefore, 1000e18);
        assertEq(usdtBalanceAfterOwner - usdtBalanceBeforeOwner, 1000e18 * 24 / 10000);
        assertEq(ico.totalSoldTokens(), 1000e18);
        assertEq(ico.totalUsdtRaised(), 1000e18 * 24 / 10000);
        assertEq(ico.remainingTokens(), 3_000_000_000_000e18 - 1000e18);
    }

    function testReverts() public {
        fundUsdt(user1, 2000e18);

        vm.prank(user1);
        vm.expectRevert();
        ico.buy(user1, 0);

        vm.expectRevert();
        ico.buy(user1, 1000e18);

        vm.prank(user1);
        vm.expectRevert();
        ico.endICO();

        uint256 balanceBefore = mkfs.balanceOf(owner);
        vm.prank(owner);
        ico.endICO();
        uint256 balanceAfter = mkfs.balanceOf(owner);
        assertEq(balanceAfter - balanceBefore, 3_000_000_000_000e18);

        vm.expectRevert();
        ico.buy(user1, 1000e18);
    }
}
