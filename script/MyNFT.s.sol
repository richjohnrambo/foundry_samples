// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MyNFT} from "../src/MyNFT.sol";

contract CloudTokenScript is Script {
    MyNFT public nft;
    // address public deployer = 0x1234567890abcdef1234567890abcdef12345678; // 设置部署者地址

    function setUp() public {}

    function run() public {
        // 开始广播交易
        vm.startBroadcast();

        // 部署 CloudToken 合约
        nft = new MyNFT();

        // 结束广播
        vm.stopBroadcast();

        // 打印合约地址和已铸造的代币数量
        console.log("MyNFT deployed at:", address(nft));
    }
}

