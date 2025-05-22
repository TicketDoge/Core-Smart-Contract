// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Handler} from "./Handler.t.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";

contract Invariant is StdInvariant, Test {
    Handler handler;

    function setUp() public {
        handler = new Handler();
        targetContract(address(handler));
    }

    function invariant_testNotFails() public pure {
        assert(true);
    }
}
