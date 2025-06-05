// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import "../src/TicketDoge.sol";
import "../test/mocks/MockAggregator.sol";

contract Deploy is Script {
    function run() external {
        // 1. Start broadcasting transactions
        vm.startBroadcast();

        MockV3Aggregator feed = new MockV3Aggregator(10, 1e9);
        // 2. Deploy the contract
        // constructor(address initialOwner, address _DAI, address wmatic, address wmaticFeed, address fravashicoinAddress)
        new TicketDoge(
            0x6Ac97c57138BD707680A10A798bAf24aCe62Ae9D,
            0x320f0Ed6Fc42b0857e2b598B5DA85103203cf5d3,
            0x2a2b00797f430F79499B3724CBBBF57b54b1F891,
            3e18,
            0x6Ac97c57138BD707680A10A798bAf24aCe62Ae9D,
            0x6Ac97c57138BD707680A10A798bAf24aCe62Ae9D,
            0x6Ac97c57138BD707680A10A798bAf24aCe62Ae9D,
            0x6Ac97c57138BD707680A10A798bAf24aCe62Ae9D,
            address(feed)
        );

        // 3. Stop broadcasting
        vm.stopBroadcast();
    }
}
