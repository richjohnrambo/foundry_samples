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

    address public user;         // 模拟一个普通用户进行铸造

    uint totalSupply = 1000000 * 10 ** 18;
    uint perMint = 10 * 10 ** 18;
    uint price = 1 * 10 ** 16; // 0.01 ETH



    function setUp() public {
        projectOwner = address(0x123); // 为项目方设置一个专用地址
        memeIssuer = address(0x456);   // 为 Meme 发行者设置一个专用地址
        user = address(0x789);         // 为模拟用户设置一个专用地址
        
        factory = new MemeFactory(); // Factory owner 默认是 msg.sender (MemeFactoryTest)
        
        // 给 projectOwner 和 memeIssuer 一些初始 Ether，这样在测试余额变化时更清晰
        // vm.deal(projectOwner, 1 ether);
        // vm.deal(memeIssuer, 1 ether);
    }

    // 测试 Meme 合约部署
    function testDeployMeme() public {
        // address memeTokenAddr = factory.deployMeme("MEME", totalSupply, perMint, price);

        // memeToken = MemeToken(memeTokenAddr);

        // assertEq(memeToken.symbol(), "MEME");
        // assertEq(memeToken.totalSupply(), totalSupply);
        // assertEq(memeToken.perMint(), perMint);
        // assertEq(memeToken.price(), price);
        // assertEq(memeToken.issuer(), factory.owner());
        // assertEq(memeToken.platformOwner(), factory.owner());

        // 使用新的 deployMeme 签名，明确指定发行者和平台方
        address memeTokenAddr = factory.deployMeme(
            "MEME",
            totalSupply,
            perMint,
            price,
            memeIssuer,   // 设置 memeIssuer 作为 MemeToken 的发行者
            projectOwner  // 设置 projectOwner 作为 MemeToken 的平台方
        );

        memeToken = MemeToken(memeTokenAddr);

        assertEq(memeToken.symbol(), "MEME");
        assertEq(memeToken.totalSupply(), totalSupply);
        assertEq(memeToken.perMint(), perMint);
        assertEq(memeToken.price(), price);
        assertEq(memeToken.issuer(), memeIssuer);       // 验证发行者
        assertEq(memeToken.platformOwner(), projectOwner); // 验证平台方
    }

    // 测试 mintMeme 方法
    function testMintMeme() public {
        address memeTokenAddr = factory.deployMeme(
            "MEME",
            totalSupply,
            perMint,
            price,
            memeIssuer,
            projectOwner
        );
        memeToken = MemeToken(memeTokenAddr);

        console.log("MemeToken total supply:", memeToken.totalSupply());
        console.log("MemeToken configured total supply limit:", totalSupply);

        // 计算用户需要支付的总金额
        // price * perMint = (1e16 wei/meme) * (1e19 meme) = 1e35 wei (100 ETH)
        uint totalAmountToPay = price * perMint; 

        // !!! 关键修改 !!!
        // 确保 user 在进行交易前有足够的 ETH
        vm.deal(user, totalAmountToPay); 

        // 记录铸造前的余额
        uint initialUserBalance = user.balance; 
        uint initialIssuerBalance = memeIssuer.balance;
        uint initialProjectBalance = projectOwner.balance;

        // 模拟用户铸造 Meme
        vm.prank(user);
        factory.mintMeme{value: totalAmountToPay}(memeTokenAddr);

        // 验证铸造后的代币余额
        assertEq(memeToken.balanceOf(user), perMint);

        // 验证 Ether 余额变化
        uint fee = totalAmountToPay / 100; // 1% 费用

        // 用户支付了费用，所以余额减少
        assertEq(user.balance, initialUserBalance - totalAmountToPay);
        
        // 发行者收到剩余的 99%
        assertEq(memeIssuer.balance, initialIssuerBalance + (totalAmountToPay - fee));
        
        // 项目方收到 1% 费用
        assertEq(projectOwner.balance, initialProjectBalance + fee);
    }

    // 测试费用分配
    function testFeeDistribution() public {
        address memeTokenAddr = factory.deployMeme(
            "MEME",
            totalSupply,
            perMint,
            price,
            memeIssuer,
            projectOwner
        );
        memeToken = MemeToken(memeTokenAddr);

        // 每次铸造所需支付的总金额
        uint expectedPayment = price * perMint; 
        
        // 确保 user 有足够的 ETH
        vm.deal(user, expectedPayment);

        uint initialUserBalance = user.balance;
        uint initialIssuerBalance = memeIssuer.balance;
        uint initialProjectBalance = projectOwner.balance;

        // 模拟用户铸造
        vm.prank(user);
        factory.mintMeme{value: expectedPayment}(memeTokenAddr);

        uint fee = expectedPayment / 100;

        assertEq(user.balance, initialUserBalance - expectedPayment);
        assertEq(memeIssuer.balance, initialIssuerBalance + (expectedPayment - fee));
        assertEq(projectOwner.balance, initialProjectBalance + fee);
    }

    // 测试铸造超过最大供应量
    function testExceedTotalSupply() public {
        address memeTokenAddr = factory.deployMeme(
            "MEME",
            perMint, // 总供应量等于每次铸造量
            perMint,
            price,
            memeIssuer,
            projectOwner
        );
        memeToken = MemeToken(memeTokenAddr);

        uint totalAmountToPay = price * perMint; // 每次铸造所需的总费用

        // 确保 user 有足够的 ETH
        vm.deal(user, totalAmountToPay * 2); // 确保有足够的 ETH 进行两次铸造

        // 第一次铸造，应该成功
        vm.prank(user);
        factory.mintMeme{value: totalAmountToPay}(memeTokenAddr);
        assertEq(memeToken.balanceOf(user), perMint);
        assertEq(memeToken.currentSupply(), perMint);

        // 尝试第二次铸造，此时会超过总供应量
        vm.prank(user);
        vm.expectRevert("Exceeds total supply");
        factory.mintMeme{value: totalAmountToPay}(memeTokenAddr);
    }
}
