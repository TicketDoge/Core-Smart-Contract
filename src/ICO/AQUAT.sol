// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract Aquatimus is ERC20Burnable {
    uint256 private constant OWNER_SHARE = 3_500_000_000_000e18;
    uint256 private constant MUSK_SHARE = 3_500_000_000_000e18;

    constructor(address _owner, address _musk) ERC20("Aquatimus", "AQUAT") {
        _mint(_owner, OWNER_SHARE);
        _mint(_musk, MUSK_SHARE);
    }
}
