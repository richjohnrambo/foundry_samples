// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;
    MemeToken public memeToken;
    address public projectOwner;
    address public memeIssuer;

    uint totalSupply = 1000000 * 10 ** 18;
    uint perMint = 10 * 10 ** 18;
    uint price = 1 * 10 ** 16; // 0.01 ETH

    function setUp() public {
        projectOwner = address(0x123);
        memeIssuer = address(0x456);
        factory = new MemeFactory();
    }

    // 测试 Meme 合约部署
    function testDeployMeme() public {
        address memeTokenAddr = factory.deployMeme("MEME", totalSupply, perMint, price);

        memeToken = MemeToken(memeTokenAddr);

        assertEq(memeToken.symbol(), "MEME");
        assertEq(memeToken.totalSupply(), totalSupply);
        assertEq(memeToken.perMint(), perMint);
        assertEq(memeToken.price(), price);
        assertEq(memeToken.owner(), memeIssuer);
    }

    // 测试 mintMeme 方法
    function testMintMeme() public payable {
        address memeTokenAddr = factory.deployMeme("MEME", totalSupply, perMint, price);
        memeToken = MemeToken(memeTokenAddr);

        uint initialIssuerBalance = memeIssuer.balance;
        uint initialProjectBalance = projectOwner.balance;

        // 用户支付 ETH 并铸造
        vm.deal(address(this), 2 * price); // 给测试合约账户一些 ETH
        factory.mintMeme{value: price}(memeTokenAddr);

        uint finalIssuerBalance = memeIssuer.balance;
        uint finalProjectBalance = projectOwner.balance;

        // 验证铸造后余额
        assertEq(memeToken.balanceOf(address(this)), perMint);
        assertEq(finalIssuerBalance, initialIssuerBalance + price * 99 / 100);
        assertEq(finalProjectBalance, initialProjectBalance + price / 100);
    }

    // 测试费用分配
    function testFeeDistribution() public payable {
        address memeTokenAddr = factory.deployMeme("MEME", totalSupply, perMint, price);
        memeToken = MemeToken(memeTokenAddr);

        uint initialIssuerBalance = memeIssuer.balance;
        uint initialProjectBalance = projectOwner.balance;

        // 用户支付费用并铸造
        vm.deal(address(this), 2 * price); // 给测试合约账户一些 ETH
        factory.mintMeme{value: price}(memeTokenAddr);

        uint fee = price / 100;
        assertEq(memeIssuer.balance, initialIssuerBalance + price - fee);
        assertEq(projectOwner.balance, initialProjectBalance + fee);
    }

    // 测试铸造超过最大供应量
    function testExceedTotalSupply() public {
        address memeTokenAddr = factory.deployMeme("MEME", totalSupply, perMint, price);
        memeToken = MemeToken(memeTokenAddr);

        // 尝试超过最大供应量铸造
        vm.deal(address(this), price);
        vm.expectRevert("Exceeds total supply");
        factory.mintMeme{value: price}(memeTokenAddr);
    }
}
