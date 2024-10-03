// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DogeCoin is ERC20 {
    uint256 constant TOTAL_SUPPLY = type(uint256).max;

    constructor() ERC20("Doge Coin", "DOGE") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
