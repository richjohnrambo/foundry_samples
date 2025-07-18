// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../src/Bank.sol"; // Adjust path if your Bank.sol is in a different location

/// @title Bank Test Suite
/// @dev Comprehensive tests for the Bank contract
contract BankTest is Test {
    Bank public bank;
    address public deployer; // Contract owner
    address public user1;
    address public user2;
    address public user3;
    address public user4; // For more complex top3 scenarios
    address public user5; // For more complex top3 scenarios

    /// @dev setUp is run before each test function to initialize the environment
    function setUp() public {
        // Use vm.addr to get predictable test addresses
        deployer = vm.addr(1);
        user1 = vm.addr(2);
        user2 = vm.addr(3);
        user3 = vm.addr(4);
        user4 = vm.addr(5);
        user5 = vm.addr(6);

        // Give test accounts some initial ETH to pay for gas
        vm.deal(deployer, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);
        vm.deal(user5, 10 ether);

        // Deploy the Bank contract as the deployer (owner)
        vm.startPrank(deployer);
        bank = new Bank();
        vm.stopPrank();
    }

    //-----------------------------------------------------------------------------------------------------------------

    // --- Constructor & Ownership Tests ---

    /// @dev Tests that the constructor correctly sets the owner
    function testConstructorSetsOwner() public {
        assertEq(bank.owner(), deployer, "Owner should be the deployer address");
    }

    /// @dev Tests initial contract ETH balance is zero
    function testInitialContractBalance() public {
        assertEq(address(bank).balance, 0, "Initial contract balance should be 0");
    }

    //-----------------------------------------------------------------------------------------------------------------

    // --- receive() Function (Deposit) Tests ---

    /// @dev Tests a single user can deposit ETH and their balance is recorded
    function testDepositSingleUser() public {
        uint256 depositAmount = 1 ether;

        vm.startPrank(user1);
        (bool success, ) = payable(address(bank)).call{value: depositAmount}("");
        assertTrue(success, "Deposit call should be successful");
        vm.stopPrank();

        // Verify user1's recorded balance
        assertEq(bank.balances(user1), depositAmount, "User1's recorded balance should match deposit");
        // Verify owner's recorded balance (due to your current receive logic)
        assertEq(bank.balances(deployer), depositAmount, "Owner's recorded balance should also increase by deposit amount");
        // Verify contract's actual ETH balance
        assertEq(address(bank).balance, depositAmount, "Contract ETH balance should match total deposits");
    }

    /// @dev Tests multiple users depositing and cumulative balances
    function testDepositMultipleUsers() public {
        uint256 depositAmount1 = 1 ether;
        uint256 depositAmount2 = 0.5 ether;

        vm.startPrank(user1);
        payable(address(bank)).call{value: depositAmount1}("");
        vm.stopPrank();

        vm.startPrank(user2);
        payable(address(bank)).call{value: depositAmount2}("");
        vm.stopPrank();

        assertEq(bank.balances(user1), depositAmount1, "User1 balance incorrect");
        assertEq(bank.balances(user2), depositAmount2, "User2 balance incorrect");
        // Owner's balance should be sum of all unique deposits (due to your current logic)
        assertEq(bank.balances(deployer), depositAmount1 + depositAmount2, "Owner's balance should be sum of all deposits");
        assertEq(address(bank).balance, depositAmount1 + depositAmount2, "Contract ETH balance incorrect");
    }

    /// @dev Tests zero value deposit (should not affect balances or top3, but transaction succeeds)
    function testDepositZeroValue() public {
        uint256 initialBankBalance = address(bank).balance;
        uint256 initialUserBalance = bank.balances(user1);
        uint256 initialOwnerBalance = bank.balances(deployer);

        vm.startPrank(user1);
        (bool success, ) = payable(address(bank)).call{value: 0}("");
        assertTrue(success, "Zero value deposit call should succeed");
        vm.stopPrank();

        assertEq(bank.balances(user1), initialUserBalance, "User balance should not change for 0 deposit");
        assertEq(bank.balances(deployer), initialOwnerBalance, "Owner balance should not change for 0 deposit");
        assertEq(address(bank).balance, initialBankBalance, "Contract ETH balance should not change for 0 deposit");
        // Top 3 should remain unchanged
        assertEq(bank.getTop3Users()[0], address(0), "Top 1 should still be zero address");
    }

    //-----------------------------------------------------------------------------------------------------------------

    // --- getBalance() Tests ---

    /// @dev Tests getBalance returns correct balance for a depositor
    function testGetBalanceForDepositor() public {
        uint256 depositAmount = 2 ether;
        vm.startPrank(user1);
        payable(address(bank)).call{value: depositAmount}("");
        vm.stopPrank();

        vm.startPrank(user1);
        assertEq(bank.getBalance(), depositAmount, "getBalance should return user1's balance");
        vm.stopPrank();
    }

    /// @dev Tests getBalance returns zero for a non-depositor
    function testGetBalanceForNonDepositor() public {
        assertEq(bank.getBalance(), 0, "getBalance should return 0 for non-depositor");
    }

    //-----------------------------------------------------------------------------------------------------------------

    // --- getTop3Users() Tests ---

    /// @dev Tests top3Users is empty initially
    function testInitialTop3Users() public {
        address[3] memory topUsers = bank.getTop3Users();
        assertEq(topUsers[0], address(0), "Initial Top 1 should be zero address");
        assertEq(topUsers[1], address(0), "Initial Top 2 should be zero address");
        assertEq(topUsers[2], address(0), "Initial Top 3 should be zero address");
    }

    /// @dev Tests top3Users with one depositor
    function testTop3UsersOneDepositor() public {
        vm.startPrank(user1);
        payable(address(bank)).call{value: 1 ether}("");
        vm.stopPrank();

        address[3] memory topUsers = bank.getTop3Users();
        assertEq(topUsers[0], user1, "Top 1 should be user1");
        assertEq(topUsers[1], address(0), "Top 2 should be zero address");
        assertEq(topUsers[2], address(0), "Top 3 should be zero address");
    }

    /// @dev Tests top3Users with three depositors in increasing order
    function testTop3UsersThreeDepositorsIncreasing() public {
        vm.startPrank(user1); payable(address(bank)).call{value: 1 ether}(""); vm.stopPrank(); // user1: 1
        vm.startPrank(user2); payable(address(bank)).call{value: 2 ether}(""); vm.stopPrank(); // user2: 2
        vm.startPrank(user3); payable(address(bank)).call{value: 3 ether}(""); vm.stopPrank(); // user3: 3

        address[3] memory topUsers = bank.getTop3Users();
        assertEq(topUsers[0], user3, "Top 1 should be user3 (3 ether)");
        assertEq(topUsers[1], user2, "Top 2 should be user2 (2 ether)");
        assertEq(topUsers[2], user1, "Top 3 should be user1 (1 ether)");
    }

    /// @dev Tests top3Users with three depositors in decreasing order
    function testTop3UsersThreeDepositorsDecreasing() public {
        vm.startPrank(user3); payable(address(bank)).call{value: 3 ether}(""); vm.stopPrank(); // user3: 3
        vm.startPrank(user2); payable(address(bank)).call{value: 2 ether}(""); vm.stopPrank(); // user2: 2
        vm.startPrank(user1); payable(address(bank)).call{value: 1 ether}(""); vm.stopPrank(); // user1: 1

        address[3] memory topUsers = bank.getTop3Users();
        assertEq(topUsers[0], user3, "Top 1 should be user3 (3 ether)");
        assertEq(topUsers[1], user2, "Top 2 should be user2 (2 ether)");
        assertEq(topUsers[2], user1, "Top 3 should be user1 (1 ether)");
    }

    /// @dev Tests top3Users with a new user displacing an existing one
    function testTop3UsersDisplacement() public {
        vm.startPrank(user1); payable(address(bank)).call{value: 3 ether}(""); vm.stopPrank(); // user1: 3
        vm.startPrank(user2); payable(address(bank)).call{value: 2 ether}(""); vm.stopPrank(); // user2: 2
        vm.startPrank(user3); payable(address(bank)).call{value: 1 ether}(""); vm.stopPrank(); // user3: 1

        address[3] memory topUsersInitial = bank.getTop3Users();
        assertEq(topUsersInitial[0], user1, "Initial Top 1 should be user1");
        assertEq(topUsersInitial[1], user2, "Initial Top 2 should be user2");
        assertEq(topUsersInitial[2], user3, "Initial Top 3 should be user3");

        // user4 deposits 4 ether, should become new Top 1
        vm.startPrank(user4); payable(address(bank)).call{value: 4 ether}(""); vm.stopPrank(); // user4: 4

        address[3] memory topUsersFinal = bank.getTop3Users();
        assertEq(topUsersFinal[0], user4, "Final Top 1 should be user4 (4 ether)");
        assertEq(topUsersFinal[1], user1, "Final Top 2 should be user1 (3 ether)");
        assertEq(topUsersFinal[2], user2, "Final Top 3 should be user2 (2 ether)");
        // user3 (1 ether) should be pushed out
    }

    /// @dev Tests top3Users with an existing user increasing balance and moving up
    function testTop3UsersExistingUserMovesUp() public {
        vm.startPrank(user1); payable(address(bank)).call{value: 4 ether}(""); vm.stopPrank(); // user1: 4
        vm.startPrank(user2); payable(address(bank)).call{value: 1 ether}(""); vm.stopPrank(); // user2: 1
        vm.startPrank(user3); payable(address(bank)).call{value: 3 ether}(""); vm.stopPrank(); // user3: 3

        address[3] memory topUsersInitial = bank.getTop3Users();
        assertEq(topUsersInitial[0], user1, "Initial Top 1 should be user1");
        assertEq(topUsersInitial[1], user3, "Initial Top 2 should be user3");
        assertEq(topUsersInitial[2], user2, "Initial Top 3 should be user2");

        // user2 deposits more (1 + 3 = 4 ether), should tie with user1 or move based on specific tie-breaking
        // Your logic puts new larger balance earlier in array if equal.
        vm.startPrank(user2); payable(address(bank)).call{value: 5 ether}(""); vm.stopPrank(); // user2: 4

        address[3] memory topUsersFinal = bank.getTop3Users();
        assertEq(topUsersFinal[0], user2, "Final Top 1 should be user2 (6 ether)"); // user2 should move to top if equal and appears later
        assertEq(topUsersFinal[1], user1, "Final Top 2 should be user1 (4 ether)");
        assertEq(topUsersFinal[2], user3, "Final Top 3 should be user3 (3 ether)");
    }

    /// @dev Test top3Users with more than 3 depositors and a user not in top3 making a deposit
    function testTop3UsersMoreThanThreeAndSorting() public {
        vm.startPrank(user1); payable(address(bank)).call{value: 6 ether}(""); vm.stopPrank(); // user1: 10
        vm.startPrank(user2); payable(address(bank)).call{value: 8 ether}(""); vm.stopPrank(); // user2: 20
        vm.startPrank(user3); payable(address(bank)).call{value: 9 ether}(""); vm.stopPrank(); // user3: 30
        vm.startPrank(user4); payable(address(bank)).call{value: 5 ether}(""); vm.stopPrank();  // user4: 5
        vm.startPrank(user5); payable(address(bank)).call{value: 3 ether}(""); vm.stopPrank(); // user5: 15

        address[3] memory topUsers = bank.getTop3Users();
        // Initial top: user3 (30), user2 (20), user1 (10)
    
   
        assertEq(topUsers[0], user3, "Top 1 should be user3 (9 ether)");
        assertEq(topUsers[1], user2, "Top 2 should be user2 (8 ether)");
        assertEq(topUsers[2], user1, "Top 3 should be user1 (6 ether)");

        // User5 (15 ether) was out of top3, now makes another deposit (15 + 15 = 30),
        // should become top1, tying with user3, but potentially replacing based on your loop logic
        vm.startPrank(user5); payable(address(bank)).call{value: 7 ether}(""); vm.stopPrank(); // user5: 30

        topUsers = bank.getTop3Users();
        assertEq(topUsers[0], user5, "Final Top 1 should be user5 (10 ether)"); // As your code puts new equal balance first
        assertEq(topUsers[1], user3, "Final Top 2 should be user3 (9 ether)");
        assertEq(topUsers[2], user2, "Final Top 3 should be user2 (8 ether)");
    }


    //-----------------------------------------------------------------------------------------------------------------

    // --- withdraw() Function Tests ---

    /// @dev Tests that only the owner can call withdraw
    function testWithdrawRevertsIfNotOwner() public {
        uint256 depositAmount = 1 ether;
        vm.startPrank(user1);
        payable(address(bank)).call{value: depositAmount}(""); // Deposit some funds for the bank
        vm.stopPrank();

        vm.expectRevert("You are not the owner");
        vm.prank(user1); // Try to call as a non-owner
        bank.withdraw(0.1 ether);
    }

    /// @dev Tests that withdraw reverts if amount is zero
    function testWithdrawRevertsIfZeroAmount() public {
        vm.expectRevert("Bank: Withdraw amount must be greater than zero");
        vm.prank(deployer);
        bank.withdraw(0);
    }

    /// @dev Tests that owner can withdraw funds from contract balance
    /// @custom:note This test relies on the fix where balances[msg.sender] -= amount; is commented out.
    /// @custom:note This test also highlights that the withdraw function does *not* check if the contract has enough balance.
    function testWithdrawByOwnerSucceeds() public {
        uint256 depositAmount = 1 ether; // Amount for user1 to deposit
        uint256 withdrawAmount = 0.5 ether; // Amount for owner to withdraw

        // User1 deposits funds into the bank
        vm.startPrank(user1);
        payable(address(bank)).call{value: depositAmount}("");
        vm.stopPrank();

        uint256 initialOwnerEthBalance = deployer.balance;
        uint256 initialBankEthBalance = address(bank).balance;

        // Owner withdraws
        vm.startPrank(deployer);
        bank.withdraw(withdrawAmount);
        vm.stopPrank();

        // Verify owner's ETH balance increased (after gas costs)
        // Using assertApproxEqAbs because of gas costs in deployer.balance
        assertApproxEqAbs(deployer.balance, initialOwnerEthBalance + withdrawAmount, 0.001 ether, "Owner's ETH balance should increase");
        // Verify bank contract's ETH balance decreased
        assertEq(address(bank).balance, initialBankEthBalance - withdrawAmount, "Bank's ETH balance should decrease");
        // Verify owner's recorded balance in 'balances' (it should NOT have changed because the line was commented out)
        // Original logic in `receive` added to `balances[owner]`. So it should be `depositAmount`.
        assertEq(bank.balances(deployer), depositAmount, "Owner's recorded balance should reflect user1's deposit, not withdrawal");
    }

    /// @dev Tests that owner cannot withdraw more than the contract's actual ETH balance
    /// @custom:note This test will FAIL with the current `withdraw` implementation because it lacks a balance check.
    /// @custom:note To make this test PASS, you must add `require(address(this).balance >= amount, "Bank: Insufficient contract balance");` to `withdraw`.
    function testWithdrawExceedsContractEthBalanceReverts() public {
        uint256 depositAmount = 0.1 ether; // Only 0.1 ETH in the bank
        uint256 withdrawAmount = 0.5 ether; // Trying to withdraw more

        // User1 deposits a small amount
        vm.startPrank(user1);
        payable(address(bank)).call{value: depositAmount}("");
        vm.stopPrank();

        // Expect revert if contract balance is insufficient
        // The specific revert message will depend on whether you add a require statement
        // If no require, transfer() will fail with a generic "ETH transfer failed" or low-level EVM error
        // vm.expectRevert("Bank: Insufficient contract balance"); // Uncomment and adjust if you add the require
        vm.startPrank(deployer);
        vm.expectRevert(); // Expect any revert (could be a low-level transfer failure)
        bank.withdraw(withdrawAmount);
        vm.stopPrank();
    }
}