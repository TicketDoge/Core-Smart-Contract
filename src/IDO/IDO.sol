// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MKFS is ERC20, Ownable {
    uint256 private constant TOTAL_SUPPLY = 3_000_000_000_000e18;

    constructor(address initialOwner) ERC20("Musk Fans", "MKFS") Ownable(initialOwner) {
        _mint(initialOwner, TOTAL_SUPPLY);
    }
}
