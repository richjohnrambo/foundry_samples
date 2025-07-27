// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../src/NFTMarket.sol";
import "../src/MyNFT.sol";
import "../src/RedToken.sol";

contract NFTMarketTest is Test {
    NFTMarket public market;
    MyNFT public nft;
    RedToken public token;

    // 使用 VmSafe.Wallet 来存储地址和私钥
    address private ownerAddr;
    uint256 private ownerPk; 

    address private buyerAddr;
    uint256 private buyerPk;

    uint256 private tokenId;
    uint256 private price = 1000 ether;
    uint256 private deadline;

    function setUp() public {
        // 使用 vm.createWallet() 来生成唯一的地址和匹配的私钥
        Vm.Wallet memory ownerWallet = vm.createWallet("owner");
        ownerAddr = ownerWallet.addr;
        ownerPk = ownerWallet.privateKey;

    Vm.Wallet memory buyerWallet = vm.createWallet("buyer");
        buyerAddr = buyerWallet.addr;
        buyerPk = buyerWallet.privateKey;

        // 设置项目方为测试 msg.sender
        vm.startPrank(ownerAddr);
        token = new RedToken("RedToken", "RED");
        nft = new MyNFT();
        // 如果 MyNFT 构造函数没有设置 owner，确保 transferOwnership 或在构造函数中设置
        // 这里假设 ownerAddr 是 MyNFT 合约的初始所有者，或者可以通过 transferOwnership 设置
        nft.transferOwnership(ownerAddr); // 让项目方能 mint NFT
        nft.mint(ownerAddr, "ipfs://mockuri"); // owner mints to themselves or another address
        market = new NFTMarket(address(nft), address(token));
        token.mint(buyerAddr, 2000 ether); // mint tokens for buyer
        nft.setApprovalForAll(address(market), true); // owner approves market to transfer their NFTs
        market.addToWhitelist(buyerAddr); // owner whitelists buyer
        market.list(0, price); // owner lists NFT
        vm.stopPrank();
    }

    // function testPermitBuy() public {
    //     deadline = block.timestamp + 1 hours;

    //     // ========== 准备白名单签名（由 owner 签） ==========
    //     // 这里的 nonce 是针对签名本身，不是 token nonces。通常这个白名单签名不需要 nonce，
    //     // 但如果你的合约需要，请确保处理。这里假设白名单签名是简单的哈希。
    //     bytes32 whitelistHash = keccak256(abi.encodePacked(buyerAddr, uint256(0), price, deadline));
    //     bytes32 ethSignedWhitelistHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", whitelistHash));
    //     (uint8 wlV, bytes32 wlR, bytes32 wlS) = vm.sign(ownerPk, ethSignedWhitelistHash); // 使用 ownerPk

    //     // ========== 准备 ERC20 permit 签名（由 buyer 签） ==========
    //     uint256 nonce = token.nonces(buyerAddr);
    //     uint256 chainId = block.chainid; // 获取当前链ID

    //     bytes32 PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    //     bytes32 structHash = keccak256(
    //         abi.encode(
    //             PERMIT_TYPEHASH,
    //             buyerAddr, // owner
    //             address(market), // spender
    //             price, // value
    //             nonce, // nonce
    //             deadline // deadline
    //         )
    //     );

    //     bytes32 domainSeparator = token.DOMAIN_SEPARATOR();

    //     bytes32 digest = keccak256(abi.encodePacked(
    //         "\x19\x01",
    //         domainSeparator,
    //         structHash
    //     ));

    //     (uint8 permitV, bytes32 permitR, bytes32 permitS) = vm.sign(buyerPk, digest); // 使用 buyerPk

    //     // ========== 执行 permit 授权 ==========
    //     vm.prank(buyerAddr); // permit 应该由 buyer 自己调用
    //     token.permit(buyerAddr, address(market), price, deadline, permitV, permitR, permitS);

    //     console.log("Chain ID:", chainId);
    //     // console.log("Recovered address (from Permit signature):", ECDSA.recover(digest, permitV, permitR, permitS)); // 可以在这里打印恢复地址进行调试

    //     // ========== 执行购买 ==========
    //     vm.prank(buyerAddr); // 购买操作应该由 buyer 调用
    //     market.permitBuy(0, price, deadline, wlV, wlR, wlS);

    //     // ========== 验证 ==========
    //     assertEq(nft.ownerOf(0), buyerAddr);
    //     // 可以添加更多断言，例如 RedToken 余额变化，listing 是否移除等
    //     assertEq(token.balanceOf(buyerAddr), 1000 ether, "Buyer's token balance should be reduced");
    //     assertEq(token.balanceOf(ownerAddr), price, "Seller (owner) should receive payment");
    //     // assertEq(market.listings(0)._1, address(0), "NFT listing should be removed");
    // }
}