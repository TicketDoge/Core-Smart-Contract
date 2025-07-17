// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import "../src/ICO/AQUAT.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        new Aquatimus(0x87212B2621c2e5E68e9c54Cb3c1cC56c8b3Aac35, 0x093481b520116517b78eaa021Ec44c23c8fbe167);
        vm.stopBroadcast();
    }
}
