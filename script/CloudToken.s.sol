// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {CloudToken} from "../src/CloudToken.sol";

contract CloudTokenScript is Script {
    CloudToken public token;
    // address public deployer = 0x1234567890abcdef1234567890abcdef12345678; // 设置部署者地址

    function setUp() public {}

    function run() public {
        // 开始广播交易
        vm.startBroadcast();

        // 部署 CloudToken 合约
        token = new CloudToken();

        // 结束广播
        vm.stopBroadcast();

        // 打印合约地址和已铸造的代币数量
        console.log("CloudToken deployed at:", address(token));
        console.log("Initial supply minted:", token.totalSupply());
    }
}

