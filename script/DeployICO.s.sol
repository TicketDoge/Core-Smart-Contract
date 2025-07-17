// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import "../src/ICO/ICO.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        new AquatimusICO(
            0x87212B2621c2e5E68e9c54Cb3c1cC56c8b3Aac35,
            0xe4a3533946ED4F13Fff1176031Ee650206c4E5Cb,
            0x55d398326f99059fF775485246999027B3197955
        );
        vm.stopBroadcast();
    }
}
