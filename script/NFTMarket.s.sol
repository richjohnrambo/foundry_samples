// script/DeployNFTMarket.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/NFTMarket.sol";
import "../src/CloudToken.sol"; // 如果你需要自己部署一个 CloudToken，也可以在脚本中部署

contract DeployNFTMarket is Script {
    function run() external {
        // 开始广播交易
        vm.startBroadcast();

         // 替换成你的已部署合约地址，或先部署再传入
        address nftContract = 0x71C95911E9a5D330f4D621842EC243EE1343292e;
        address paymentToken = 0x8464135c8F25Da09e49BC8782676a84730C318bC;

        NFTMarket market = new NFTMarket(nftContract, paymentToken);

        // 结束广播
        vm.stopBroadcast();

        // 打印合约地址和已铸造的代币数量
        console.log("NFTMarket deployed at:", address(market));

    }
}
