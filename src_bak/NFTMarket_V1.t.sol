// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
// 直接从源文件导入 CloudNFT 和 CloudToken
import "../src/CloudNFT.sol";
import "../src/CloudToken.sol";
import "../src/NFTMarket_V1.sol";
import "../src/NFTMarket_V2.sol";

contract NFTMarket_V1_Test is Test {
    NFTMarket_V1 public market;
    CloudNFT public nftContract;
    CloudToken public paymentToken;

    // Test addresses
    address public deployer;
    address public seller;
    address public buyer;
    
    // Test constants
    uint256 public constant LISTING_PRICE = 1 ether;
    uint256 public constant INITIAL_TOKEN_BALANCE = 100 ether;
    string public constant TEST_URI = "https://example.com/nft/1";

    function setUp() public {
        deployer = vm.addr(1);
        seller = vm.addr(2);
        buyer = vm.addr(3);

        vm.startPrank(deployer);
        // 部署 mock contracts，CloudToken 仍为普通合约
        paymentToken = new CloudToken();

        // 部署可升级的 CloudNFT 合约
        // 1. 部署 CloudNFT 实现合约
        CloudNFT nftImpl = new CloudNFT();
        // 2. 部署 ProxyAdmin
         // 2. 部署 ProxyAdmin，并传入初始所有者地址
        ProxyAdmin admin = new ProxyAdmin(deployer);
        // 3. 部署代理合约并调用 CloudNFT 的 initialize 函数
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(nftImpl),
            address(admin),
            abi.encodeWithSelector(nftImpl.initialize.selector)
        );
        // 4. 将代理地址转换为 CloudNFT 类型
        nftContract = CloudNFT(address(proxy));
        
        // 部署 NFTMarket_V1 实现合约
        NFTMarket_V1 marketImpl = new NFTMarket_V1();
        
        // 部署 NFTMarket_V1 的代理合约并初始化
        TransparentUpgradeableProxy marketProxy = new TransparentUpgradeableProxy(
            address(marketImpl),
            address(admin),
            abi.encodeWithSelector(
                marketImpl.initialize.selector,
                address(nftContract),
                address(paymentToken)
            )
        );
        market = NFTMarket_V1(address(marketProxy));
        vm.stopPrank();

        // 为测试账户设置初始状态
        vm.startPrank(deployer);
        paymentToken.mint(buyer, INITIAL_TOKEN_BALANCE);
        
        // 将 NFT 所有权转移给测试中的 seller，并铸造 NFT
        // 这里使用新的 mint 函数
        nftContract.transferOwnership(seller);
        vm.stopPrank();
    }

    /**
     * @notice Test a successful listing of an NFT.
     */
    function testList_Success() public {
        // seller 铸造 NFT 并列表
        vm.startPrank(seller);
        uint256 tokenId = nftContract.mint(seller, TEST_URI);
        nftContract.approve(address(market), tokenId);
        market.list(tokenId, LISTING_PRICE);
        vm.stopPrank();
        
        // Assert listing data - 正确的访问方式
        (uint256 price, address sellerAddress) = market.listings(tokenId);
        assertEq(price, LISTING_PRICE);
        assertEq(sellerAddress, seller);
        
        // Assert NFT ownership
        assertEq(nftContract.ownerOf(tokenId), address(market));
    }

    /**
     * @notice Test that a listing fails if the caller is not the owner.
     */
    function testList_RevertsIfNotOwner() public {
        vm.startPrank(seller);
        uint256 tokenId = nftContract.mint(seller, TEST_URI);
        vm.stopPrank();
        
        vm.startPrank(buyer);
        vm.expectRevert("You must own the NFT");
        market.list(tokenId, LISTING_PRICE);
        vm.stopPrank();
    }

    /**
     * @notice Test a successful purchase of an NFT.
     */
    function testBuyNFT_Success() public {
        // First, list the NFT
        vm.startPrank(seller);
        uint256 tokenId = nftContract.mint(seller, TEST_URI);
        nftContract.approve(address(market), tokenId);
        market.list(tokenId, LISTING_PRICE);
        vm.stopPrank();
        
        // Then, the buyer approves the market to take the payment token
        vm.startPrank(buyer);
        paymentToken.approve(address(market), LISTING_PRICE);
        market.buyNFT(tokenId);
        vm.stopPrank();
        
        // Assert NFT ownership transferred to the buyer
        assertEq(nftContract.ownerOf(tokenId), buyer);
        
        // Assert payment transferred to the seller
        assertEq(paymentToken.balanceOf(seller), LISTING_PRICE);
        assertEq(paymentToken.balanceOf(buyer), INITIAL_TOKEN_BALANCE - LISTING_PRICE);
        
        // Assert listing is deleted - 正确的访问方式
        (uint256 price, ) = market.listings(tokenId);
        assertEq(price, 0);
    }
}
