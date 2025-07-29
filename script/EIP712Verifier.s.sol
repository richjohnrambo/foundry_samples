// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/EIP712Verifier.sol";


contract CounterScript is Script  {


    //  function saveContract(string memory name, address addr) public {
    //     string memory chainId = vm.toString(block.chainid);
        
    //     string memory json1 = "key";
    //     string memory finalJson =  vm.serializeAddress(json1, "address", addr);
    //     string memory dirPath = string.concat(string.concat("deployments/", name), "_");
    //     vm.writeJson(finalJson, string.concat(dirPath, string.concat(chainId, ".json"))); 
    // }


    function setUp() public {}

    function run() public {
        // 开始广播交易
        vm.startBroadcast();

        EIP712Verifier verifier = new EIP712Verifier();
        console.log("EIP712Verifier deployed on %s", address(verifier));
        // saveContract("EIP712Verifier", address(verifier));

        // 结束广播
        vm.stopBroadcast();
    }

}
