// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

contract MyTokenScript is Script {
    MyToken public token;
    string public name = "RamboToken";  // 代币名称
    string public symbol = "RBT";       // 代币符号

    function setUp() public {}

    function run() public {
        // 开始广播交易
        vm.startBroadcast();

        // 部署 MyToken 合约，传入代币名称和符号
        token = new MyToken(name, symbol);

        // 结束广播
        vm.stopBroadcast();

        // 打印合约地址和已铸造的代币数量
        console.log("MyToken deployed at:", address(token));
        console.log("Initial supply minted:", token.totalSupply());
    }
}
