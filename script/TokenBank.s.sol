// script/DeployNFTMarket.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TokenBank.sol"; // 如果你需要自己部署一个 CloudToken，也可以在脚本中部署

contract DeployTokenBank is Script {
    function run() external {
        // 开始广播交易
        vm.startBroadcast();

        address paymentToken = 0x38A13792AE14dF9d6643C6F35B0B6F1dBA4D8ccd;

        TokenBank tokenBank = new TokenBank(paymentToken);

        // 结束广播
        vm.stopBroadcast();

        // 打印合约地址和已铸造的代币数量
        console.log("TokenBank deployed at:", address(tokenBank));

    }
}
