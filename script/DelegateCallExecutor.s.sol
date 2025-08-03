// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {DelegateCallExecutor} from "../src/DelegateCallExecutor.sol";

contract DelegateCallExecutorScript is Script {
    DelegateCallExecutor public delegateCallExecutor;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        delegateCallExecutor = new DelegateCallExecutor();

        vm.stopBroadcast();
    }
}
