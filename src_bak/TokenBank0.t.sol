// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TokenBank.sol";
import "../src/CloudToken.sol";

contract TokenBankTest is Test {
    TokenBank tokenBank;
    CloudToken cloudToken;
    address user = address(0x123);
    address admin = address(0x456);

    // 部署时，先部署 CloudToken 合约，再部署 TokenBank 合约
    function setUp() public {
        cloudToken = new CloudToken();
        tokenBank = new TokenBank(address(cloudToken));

        // 向测试用户分配一定的 Token
        cloudToken.mint(user, 1000 * 10**18);
        
        // 确保用户批准 TokenBank 合约转移一定数量的代币
        vm.startPrank(user); // 模拟用户操作
        cloudToken.approve(address(tokenBank), 1000 * 10**18);
        vm.stopPrank();
    }

    // 测试存款功能
    function testDeposit() public {
        uint depositAmount = 100 * 10**18;

        // 获取用户存款前的余额
        uint initialBalance = tokenBank.getDepositBalance(user);

        // 存款操作
        vm.startPrank(user);
        tokenBank.deposit(depositAmount);
        vm.stopPrank();

        // 验证存款后的余额
        uint newBalance = tokenBank.getDepositBalance(user);
        assertEq(newBalance, initialBalance + depositAmount, "Deposit failed.");

        // 验证 TokenBank 中的总供应量
        uint newTotalSupply = tokenBank.totalSupply();
        assertEq(newTotalSupply, depositAmount, "Total supply mismatch.");
    }

    // 测试提取功能
    function testWithdraw() public {
        uint depositAmount = 100 * 10**18;

        // 存款前，进行存款
        vm.startPrank(user);
        tokenBank.deposit(depositAmount);
        vm.stopPrank();

        // 获取存款后的余额
        uint initialBalance = tokenBank.getDepositBalance(user);
        
        // 提取操作
        vm.startPrank(user);
        tokenBank.withdraw(depositAmount);
        vm.stopPrank();

        // 验证提取后的余额
        uint newBalance = tokenBank.getDepositBalance(user);
        assertEq(newBalance, initialBalance - depositAmount, "Withdraw failed.");

        // 确保提取后 TokenBank 中的总供应量减少
        uint newTotalSupply = tokenBank.totalSupply();
        assertEq(newTotalSupply, 0, "Total supply mismatch after withdrawal.");
    }

    // 测试用户余额不足时的提取
    function testWithdrawInsufficientBalance() public {
        uint depositAmount = 100 * 10**18;

        // 存款前，进行存款
        vm.startPrank(user);
        tokenBank.deposit(depositAmount);
        vm.stopPrank();

        // 用户试图提取超过余额的金额
        vm.startPrank(user);
        vm.expectRevert("Insufficient balance.");
        tokenBank.withdraw(depositAmount + 1);
        vm.stopPrank();
    }

    // 测试存款金额为 0 的场景
    function testDepositZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert("Deposit amount must be greater than zero.");
        tokenBank.deposit(0);
        vm.stopPrank();
    }

    // 测试 TokenBank 合约不能自己存款
    function testInvalidDepositByContract() public {
        vm.startPrank(address(tokenBank));
        vm.expectRevert("Invalid recipient");
        tokenBank.deposit(100 * 10**18);
        vm.stopPrank();
    }
}
