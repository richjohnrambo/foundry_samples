// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {NFTMarket} from "../src/NFTMarket.sol";  // 引入NFTMarket合约      // 引入Forge的Script功能
import "forge-std/Script.sol";
import "../src/CloudToken.sol"; 
import {MyNFT} from "../src/MyNFT.sol";

contract InteractNFTMarket is Script {


    function run() public {
        MyNFT mockNFT = MyNFT(0x71C95911E9a5D330f4D621842EC243EE1343292e); // 已部署的 NFT 合约
        CloudToken mockToken = CloudToken(0x8464135c8F25Da09e49BC8782676a84730C318bC); // 已部署的 ERC20 合约
        NFTMarket market = NFTMarket(0x948B3c65b89DF0B4894ABE91E6D02FE579834F8F); // 已部署的 Market 合约
        // 1. 用 owner mint
        address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        address nftOwner = mockNFT.owner();
        vm.startBroadcast(nftOwner);
        mockNFT.mint(alice, "uri_alice_1");
        vm.stopBroadcast();

        // 2. 用 alice 授权和上架
        vm.startBroadcast(alice);
        mockNFT.setApprovalForAll(address(market), true);
        market.list(0, 1000);
        vm.stopBroadcast();

    }

    // NFTMarket public market;
    // MyNFT public mockNFT;
    // CloudToken public mockToken;

    // // Test accounts
    // address public deployer;
    // address public alice;
    // address public bob;
    // address public charlie;

    // // Fixed NFT IDs for specific test cases
    // uint256 internal constant ALICE_NFT_ID_0 = 0;
    // uint256 internal constant ALICE_NFT_ID_1 = 1;

    // function setUp() public {
    //     // 定义账户地址
    //     deployer = 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955;  // 假设这是合约的所有者
    //     alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    //     bob = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
    //     charlie = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;

    //     // 为账户分配ETH
    //     vm.deal(deployer, 1 ether);
    //     vm.deal(alice, 1 ether);
    //     vm.deal(bob, 1 ether);
    //     vm.deal(charlie, 1 ether);

    //     // 使用已经部署的合约地址
    //     mockNFT = MyNFT(0x71C95911E9a5D330f4D621842EC243EE1343292e); // 已部署的 NFT 合约
    //     mockToken = CloudToken(0x8464135c8F25Da09e49BC8782676a84730C318bC); // 已部署的 ERC20 合约
    //     market = NFTMarket(0x948B3c65b89DF0B4894ABE91E6D02FE579834F8F); // 已部署的 Market 合约

    //     // 合约操作：确认所有者有权限执行 mint 和授权
    //     vm.startPrank(mockNFT.owner());  // 模拟 deployer 为合约的所有者
    //     mockNFT.mint(alice, "uri_alice_0");
    //     mockNFT.mint(alice, "uri_alice_1");
    //     vm.stopPrank();

    //     vm.startPrank(mockToken.owner());  // 继续模拟 deployer 执行操作
    //     mockToken.mint(bob, 5000 * 10 ** mockToken.decimals());
    //     vm.stopPrank();

    //     // alice 设置授权
    //     // vm.startPrank(mockNFT.owner());
    //     // mockNFT.setApprovalForAll(address(market), true);  // alice 授权市场合约管理 NFT
    //     // vm.stopPrank();

    //     vm.startPrank(alice);
    //     mockNFT.setApprovalForAll(address(market), true);  // alice 授权市场合约管理 NFT
    //     vm.stopPrank();

    //     // bob 和 charlie 授权支付
    //     vm.startPrank(bob);
    //     mockToken.approve(address(market), type(uint256).max);  // bob 授权市场合约支付
    //     vm.stopPrank();

    //     // vm.startPrank(charlie);
    //     // mockToken.approve(address(market), type(uint256).max);  // charlie 授权市场合约支付
    //     // vm.stopPrank();
    // }




}
