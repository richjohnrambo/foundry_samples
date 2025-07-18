// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/CloudToken.sol";

contract CloudTokenTest is Test {
    CloudToken public token;
    address user1;
    address user2;

    function setUp() public {
        // token = new CloudToken();
        // user1 = vm.addr(1);
        // user2 = vm.addr(2);

        //  // 打印合约地址和初始发行量
        // console.log("CloudToken deployed at:", address(token));
        // console.log("Total supply:", token.totalSupply());

        // // 给 user1 分配一些 token
        // token.transfer(user1, 1000);
    }

    function testTransfer() public {
        // vm.prank(user1);
        // bool success = token.transfer(user2, 100);
        // assertTrue(success);
        // assertEq(token.balanceOf(user2), 100 );
        // assertEq(token.balanceOf(user1), 900 );
    }

    function testApproveAndAllowance() public {
        // vm.prank(user1);
        // bool approved = token.approve(user2, 500 );
        // assertTrue(approved);
        // uint256 allow = token.allowance(user1, user2);
        // assertEq(allow, 500 );
    }

    function testRevert_TransferOverBalance() public {
        // vm.prank(user1);
        // token.transfer(user2, 2000 ); // 超过 user1 的余额，应该失败
    }
}
