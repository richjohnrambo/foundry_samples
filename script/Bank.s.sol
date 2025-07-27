// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Bank} from "../src/Bank.sol";

contract BankScript is Script {
    Bank public token;
    // address public deployer = 0x1234567890abcdef1234567890abcdef12345678; // 设置部署者地址

    function setUp() public {}

    function run() public {
        // 开始广播交易
        vm.startBroadcast();

        // 部署 CloudToken 合约
        token = new Bank();

        // 结束广播
        vm.stopBroadcast();

        // 打印合约地址和已铸造的代币数量
        console.log("Bank deployed at:", address(token));

    }
}

