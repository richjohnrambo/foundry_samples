// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../src/NFTMarket.sol";
import "../src/MyNFT.sol";
import "../src/RedToken.sol";

contract NFTMarketTest is Test { // Assuming the contract name is NFTMarketTest, not NFTMarket2.t.sol
    NFTMarket public market;
    MyNFT public nft;
    RedToken public token;

    address private ownerAddr;
    uint256 private ownerPk; 

    address private buyerAddr;
    uint256 private buyerPk;

    uint256 private tokenId;
    uint256 private constant LISTING_AND_PERMIT_PRICE = 100 ether;

    uint256 private deadline;

    function setUp() public {
        Vm.Wallet memory ownerWallet = vm.createWallet("owner");
        ownerAddr = ownerWallet.addr;
        ownerPk = ownerWallet.privateKey;

        Vm.Wallet memory buyerWallet = vm.createWallet("buyer");
        buyerAddr = buyerWallet.addr;
        buyerPk = buyerWallet.privateKey;

        vm.startPrank(ownerAddr);
        token = new RedToken("RedToken", "RED");
        nft = new MyNFT();
        nft.transferOwnership(ownerAddr);
        nft.mint(ownerAddr, "ipfs://mockuri");
        market = new NFTMarket(address(nft), address(token));
        token.mint(buyerAddr, 2000 ether);
        nft.setApprovalForAll(address(market), true);
        market.addToWhitelist(buyerAddr);
        market.list(0, LISTING_AND_PERMIT_PRICE);
        vm.stopPrank();
    }

    function testPermitBuy() public {
        deadline = block.timestamp + 1 hours;

        // ===========================================
        // 1. 生成白名单签名 (由 owner 签)
        // ===========================================
        bytes32 whitelistMessageHash = keccak256(abi.encodePacked(buyerAddr, tokenId, LISTING_AND_PERMIT_PRICE, deadline));
        bytes32 ethSignedWhitelistHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", whitelistMessageHash));
        (uint8 wlV, bytes32 wlR, bytes32 wlS) = vm.sign(ownerPk, ethSignedWhitelistHash);

        address recoveredWhitelistSignerFromTest = ECDSA.recover(ethSignedWhitelistHash, wlV, wlR, wlS);
        console.log("Expected ownerAddr for Whitelist:", ownerAddr);
        console.log("Recovered signer from Whitelist (in Test):", recoveredWhitelistSignerFromTest);
        assertEq(recoveredWhitelistSignerFromTest, ownerAddr, "Whitelist signature recovery failed in test");


        // ===========================================
        // 2. 生成 ERC20 Permit 签名 (由 buyer 签)
        // ===========================================
        uint256 nonce = token.nonces(buyerAddr); 
        uint256 chainId = block.chainid;

        bytes32 PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                buyerAddr,
                address(market),
                LISTING_AND_PERMIT_PRICE,
                nonce,
                deadline
            )
        );

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();

        bytes32 permitDigest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));

        (uint8 permitV, bytes32 permitR, bytes32 permitS) = vm.sign(buyerPk, permitDigest);

        address recoveredPermitSignerFromTest = ECDSA.recover(permitDigest, permitV, permitR, permitS);
        console.log("Expected buyerAddr for Permit:", buyerAddr);
        console.log("Recovered signer from Permit (in Test):", recoveredPermitSignerFromTest);
        assertEq(recoveredPermitSignerFromTest, buyerAddr, "Permit signature recovery failed in test");
        console.log("Chain ID:", chainId);


        // ===========================================
        // 3. 执行购买 (传入两套签名参数)
        // ===========================================
        vm.prank(buyerAddr);
        // FIX: Add the permitV, permitR, permitS arguments here
        market.permitBuy(
            0, // tokenId
            LISTING_AND_PERMIT_PRICE, // price (using the constant now)
            deadline,  wlV, wlR, wlS,      // Whitelist signature parameters
            permitV, permitR, permitS // ERC20 Permit signature parameters
        ); 

        // ===========================================
        // 4. 验证购买结果
        // ===========================================
        assertEq(nft.ownerOf(0), buyerAddr, "NFT should be owned by buyer");
        assertEq(token.balanceOf(buyerAddr), 2000 ether - LISTING_AND_PERMIT_PRICE, "Buyer's token balance should be reduced");
        assertEq(token.balanceOf(ownerAddr), LISTING_AND_PERMIT_PRICE, "Seller (owner) should receive payment");
        // assertEq(market.listings(0).seller, address(0), "NFT listing should be removed");
    }
}