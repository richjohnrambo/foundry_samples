// scripts/DeployPermit2.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "@uniswap/permit2/contracts/Permit2.sol"; // 导入 Permit2 实现合约

contract DeployPermit2 is Script {
    function run() public returns (address permit2Address) {
        vm.startBroadcast();

        Permit2 permit2 = new Permit2();
        permit2Address = address(permit2);
        console.log("Permit2 deployed at:", permit2Address);

        vm.stopBroadcast();
    }
}