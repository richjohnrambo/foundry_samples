// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TokenBank.sol";
import "../src/RedToken.sol";

contract TokenBankTest is Test {
    TokenBank2 public tokenBank;
    RedToken public redToken;

    address user;
    uint256 userPk;

    uint256 constant amount = 1000;
    uint256 deadline;

    function setUp() public {
        // 生成用户私钥和地址
        userPk = 0xA11CE; // 自定义一个私钥
        user = vm.addr(userPk);

        // 部署 ERC20 和 TokenBank
        redToken = new RedToken("RedToken", "RED");
        tokenBank = new TokenBank(address(redToken));

        // 给用户铸币
        redToken.mint(user, amount);

        // 设置 deadline
        deadline = block.timestamp + 1 hours;
    }

    function testPermitDeposit() public {
        // 构造 EIP-2612 permit digest
        uint256 chainId = block.chainid;

        bytes32 DOMAIN_SEPARATOR = redToken.DOMAIN_SEPARATOR();
        bytes32 PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        uint256 nonce = redToken.nonces(user);

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                user,
                address(tokenBank),
                amount,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                structHash
            )
        );

        // 用用户私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

        // 使用 permitDeposit，无需 approve
        vm.prank(user);
        tokenBank.permitDeposit(amount, deadline, v, r, s);

        // 验证存款成功
        assertEq(tokenBank.getDepositBalance(user), amount);
        assertEq(redToken.balanceOf(address(tokenBank)), amount);
    }
}
