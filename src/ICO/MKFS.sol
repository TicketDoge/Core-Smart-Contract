// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MKFS is ERC20Burnable {
    uint256 private constant TOTAL_SUPPLY = 3_500_000_000_000e18;

    constructor(address initialOwner) ERC20("Testing Token", "TT") {
        _mint(initialOwner, TOTAL_SUPPLY);
    }
}
