// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";


import "../src/CloudNFT.sol";
import "../src/CloudToken.sol";
import "../src/NFTMarket_V1.sol";
import "../src/NFTMarket_V2.sol";

contract NFTMarket_V2_Test is Test {
    // 主测试合约，将用作升级后的 V2 合约
    NFTMarket_V2 public market;
    
    // V1 和 V2 实现合约
    NFTMarket_V1 public marketImplV1;
    NFTMarket_V2 public marketImplV2;

    CloudNFT public nftContract;
    CloudToken public paymentToken;
    ProxyAdmin public proxyAdmin;

    // 测试账户地址
    address public deployer;
    address public seller;
    address public buyer;
    
    // 铸造的 NFT 的 tokenId
    uint256 public nftTokenId;
    
    // 测试常量
    uint256 public constant LISTING_PRICE = 1 ether;
    uint256 public constant INITIAL_TOKEN_BALANCE = 100 ether;
    
    // 用于测试的代理合约
    TransparentUpgradeableProxy public marketProxy;

    function setUp() public {
        deployer = vm.addr(1);
        seller = vm.addr(2);
        buyer = vm.addr(3);

        vm.startPrank(deployer);
        
        // 部署 CloudNFT 实现合约
        CloudNFT nftImpl = new CloudNFT();
        // 部署 CloudToken 实现合约 (非代理合约)
        paymentToken = new CloudToken();
        
        // 部署 V1 和 V2 市场实现合约，但暂不初始化
        marketImplV1 = new NFTMarket_V1();
        marketImplV2 = new NFTMarket_V2();
        
        // 部署代理管理员合约
        proxyAdmin = new ProxyAdmin(deployer);

        // 部署并初始化 CloudNFT 代理合约
        TransparentUpgradeableProxy nftProxy = new TransparentUpgradeableProxy(
            address(nftImpl),
            address(proxyAdmin),
            abi.encodeWithSelector(nftImpl.initialize.selector)
        );
        nftContract = CloudNFT(address(nftProxy));
        
        // 部署市场代理合约并使用 V1 实现合约进行初始化
        marketProxy = new TransparentUpgradeableProxy(
            address(marketImplV1),
            address(proxyAdmin),
            abi.encodeWithSelector(
                marketImplV1.initialize.selector,
                address(nftContract),
                address(paymentToken)
            )
        );
        // 将市场代理的地址赋给 `market` 变量以便于测试
        market = NFTMarket_V2(address(marketProxy));


        // 设置测试账户的状态
        // 为卖家铸造一个 NFT 并获取 tokenId
        nftTokenId = nftContract.mint(seller, "https://example.com/nft/1");
        // 为买家铸造测试代币
        paymentToken.mint(buyer, INITIAL_TOKEN_BALANCE);
        
        vm.stopPrank();

        // 验证 NFT 已正确铸造给卖家
        assertEq(nftContract.ownerOf(nftTokenId), seller, "NFT should be minted to seller");
        // 验证买家有足够的代币用于购买
        assertEq(paymentToken.balanceOf(buyer), INITIAL_TOKEN_BALANCE, "Buyer should have initial token balance");
        // 验证卖家初始代币余额为零
        assertEq(paymentToken.balanceOf(seller), 0, "Seller should have no initial token balance");
    }

    /**
     * @notice 测试通过 EIP-712 签名成功挂单 NFT。
     * 此测试要求合约首先升级到 V2。
     */
    function testListWithSignature_Success() public {
        // 首先，使用 ProxyAdmin 函数将市场合约升级到 V2
        // 正确的做法是使用 ProxyAdmin 的所有者（即 deployer）来执行此操作
        vm.prank(deployer);
        // 使用 upgradeAndCall 方法进行升级，并传递空数据 "0x"
        // 这是一个强制类型转换，它告诉编译器将代理合约地址视为实现了 ITransparentUpgradeableProxy 的接口。
        // 这是旧版 OpenZeppelin 透明代理模式的特有设计。
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(marketProxy)), address(marketImplV2), "0x");

        // 卖家必须授权市场合约操作所有 NFT
        vm.startPrank(seller);
        nftContract.setApprovalForAll(address(market), true);
        vm.stopPrank();

        // 准备并签名挂单数据
        uint256 nonce = market.nonces(seller); 
        (bytes32 digest, bytes memory signature) = getEIP712Signature(seller, nftTokenId, LISTING_PRICE, nonce);

        // 模拟第三方（或买家）调用此函数
        vm.startPrank(buyer);
        market.listWithSignature(nftTokenId, LISTING_PRICE, signature);
        vm.stopPrank();

        // 验证挂单数据
        (uint256 price, address sellerAddress, bool isSignedListing) = market.listings(nftTokenId);
        assertEq(price, LISTING_PRICE, "Price should match listing price");
        assertEq(sellerAddress, seller, "Seller address should be correct");
        assertTrue(isSignedListing, "Listing should be marked as signed");

        // 验证 NFT 的所有权仍归属于卖家，因为这是 V2 签名挂单
        assertEq(nftContract.ownerOf(nftTokenId), seller, "NFT ownership should remain with seller");
    }
    
    /**
     * @notice 测试购买通过新签名方法挂单的 NFT。
     * 此测试要求合约首先升级到 V2。
     */
    function testBuyNFT_V2Listing_Success() public {
        // 首先，使用 ProxyAdmin 函数将市场合约升级到 V2
        // 正确的做法是使用 ProxyAdmin 的所有者（即 deployer）来执行此操作
        vm.prank(deployer);
        // 这是一个强制类型转换，它告诉编译器将代理合约地址视为实现了 ITransparentUpgradeableProxy 的接口。
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(marketProxy)), address(marketImplV2), "0x");

        // 首先，通过签名挂单 NFT
        vm.startPrank(seller);
        nftContract.setApprovalForAll(address(market), true);
        vm.stopPrank();

        uint256 nonce = market.nonces(seller);
        (bytes32 digest, bytes memory signature) = getEIP712Signature(seller, nftTokenId, LISTING_PRICE, nonce);
        
        // 模拟买家或另一个第三方调用
        vm.startPrank(buyer);
        market.listWithSignature(nftTokenId, LISTING_PRICE, signature);
        
        // 然后，买家授权市场合约转移支付代币
        paymentToken.approve(address(market), LISTING_PRICE);
        market.buyNFT(nftTokenId);
        vm.stopPrank();

        // 验证 NFT 的所有权已转移给买家
        assertEq(nftContract.ownerOf(nftTokenId), buyer, "NFT should be owned by buyer");
        
        // 验证支付代币已转移给卖家
        assertEq(paymentToken.balanceOf(seller), LISTING_PRICE, "Seller should receive payment");
        assertEq(paymentToken.balanceOf(buyer), INITIAL_TOKEN_BALANCE - LISTING_PRICE, "Buyer's token balance should decrease");
        
        // 验证挂单已被移除
        (uint256 price, , ) = market.listings(nftTokenId);
        assertEq(price, 0, "Listing should be removed after purchase");
    }
    
    /**
     * @notice 测试购买通过旧的 V1 方法挂单的 NFT。
     * 此测试模拟从 V1 升级到 V2，并验证 V2 的向后兼容性。
     */
    function testBuyNFT_V1Listing_Success() public {
        // 1. 卖家通过 V1 市场（当前未升级的代理合约）挂单 NFT
        vm.startPrank(seller);
        // V1 挂单需要先授权，因为它会转移 NFT 所有权
        nftContract.approve(address(market), nftTokenId);
        NFTMarket_V1(address(market)).list(nftTokenId, LISTING_PRICE);
        vm.stopPrank();

        // 检查 NFT 是否已由 V1 市场合约持有
        assertEq(nftContract.ownerOf(nftTokenId), address(market), "NFT should be held by V1 market contract");
        
        // 2. 模拟管理员将合约升级到 V2
        // 正确的做法是使用 ProxyAdmin 的所有者（即 deployer）来执行此操作
        vm.prank(deployer);
        // 这是一个强制类型转换，它告诉编译器将代理合约地址视为实现了 ITransparentUpgradeableProxy 的接口。
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(marketProxy)), address(marketImplV2), "0x");
        
        // 3. 买家使用升级后的 V2 市场合约购买在 V1 上挂单的 NFT
        vm.startPrank(buyer);
        paymentToken.approve(address(market), LISTING_PRICE);
        market.buyNFT(nftTokenId);
        vm.stopPrank();
        
        // 4. 验证 NFT 所有权和支付转移
        assertEq(nftContract.ownerOf(nftTokenId), buyer, "NFT should be owned by buyer after purchase");
        assertEq(paymentToken.balanceOf(seller), LISTING_PRICE, "Seller should receive payment from V2 market");
        
        // 验证挂单已被移除
        (uint256 price, , ) = market.listings(nftTokenId);
        assertEq(price, 0, "Listing should be removed after purchase");
    }
    
    /**
     * @notice 新测试：如果签名无效，`listWithSignature` 函数应该回滚。
     */
    function testListWithSignature_InvalidSignature_Reverts() public {
        // 首先，使用 ProxyAdmin 函数将市场合约升级到 V2
        // 正确的做法是使用 ProxyAdmin 的所有者（即 deployer）来执行此操作
        vm.prank(deployer);
        // 这是一个强制类型转换，它告诉编译器将代理合约地址视为实现了 ITransparentUpgradeableProxy 的接口。
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(marketProxy)), address(marketImplV2), "0x");

        // 卖家授权市场合约
        vm.startPrank(seller);
        nftContract.setApprovalForAll(address(market), true);
        vm.stopPrank();

        // 使用错误的签名者地址生成签名
        uint256 nonce = market.nonces(seller);
        // 使用不正确的地址（例如，买家）来生成签名，但声称来自卖家
        (bytes32 digest, bytes memory invalidSignature) = getEIP712Signature(buyer, nftTokenId, LISTING_PRICE, nonce);

        vm.startPrank(buyer);
        // 由于签名者不匹配，交易预期会回滚
        vm.expectRevert("Invalid signature");
        market.listWithSignature(nftTokenId, LISTING_PRICE, invalidSignature);
        vm.stopPrank();
    }
    
    /**
     * @notice 新测试：当尝试挂单一个已经挂单的 NFT 时回滚。
     */
    function testListWithSignature_AlreadyListed_Reverts() public {
        // 首先，使用 ProxyAdmin 函数将市场合约升级到 V2
        // 正确的做法是使用 ProxyAdmin 的所有者（即 deployer）来执行此操作
        vm.prank(deployer);
        // 这是一个强制类型转换，它告诉编译器将代理合约地址视为实现了 ITransparentUpgradeableProxy 的接口。
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(marketProxy)), address(marketImplV2), "0x");

        // 首先，通过签名挂单 NFT
        vm.startPrank(seller);
        nftContract.setApprovalForAll(address(market), true);
        uint256 nonce = market.nonces(seller);
        (bytes32 digest, bytes memory signature) = getEIP712Signature(seller, nftTokenId, LISTING_PRICE, nonce);
        market.listWithSignature(nftTokenId, LISTING_PRICE, signature);
        vm.stopPrank();

        // 再次尝试挂单
        vm.startPrank(seller);
        vm.expectRevert("NFT already listed");
        market.listWithSignature(nftTokenId, LISTING_PRICE, signature);
        vm.stopPrank();
    }

    /**
     * @notice 新测试：如果买家没有足够的代币，则回滚。
     */
    function testBuyNFT_NotEnoughTokens_Reverts() public {
        // 首先，使用 ProxyAdmin 函数将市场合约升级到 V2
        // 正确的做法是使用 ProxyAdmin 的所有者（即 deployer）来执行此操作
        vm.prank(deployer);
        // 这是一个强制类型转换，它告诉编译器将代理合约地址视为实现了 ITransparentUpgradeableProxy 的接口。
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(marketProxy)), address(marketImplV2), "0x");

        // 卖家通过签名挂单 NFT
        vm.startPrank(seller);
        nftContract.setApprovalForAll(address(market), true);
        uint256 nonce = market.nonces(seller);
        (bytes32 digest, bytes memory signature) = getEIP712Signature(seller, nftTokenId, LISTING_PRICE, nonce);
        market.listWithSignature(nftTokenId, LISTING_PRICE, signature);
        vm.stopPrank();

        // 将买家的代币余额设置为不足
        vm.startPrank(deployer);
        paymentToken.mint(buyer, LISTING_PRICE - 1);
        vm.stopPrank();

        vm.startPrank(buyer);
        // 授权市场合约
        paymentToken.approve(address(market), LISTING_PRICE);
        // 由于代币不足，交易预期会回滚
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        market.buyNFT(nftTokenId);
        vm.stopPrank();
    }
    
    /**
     * @notice 新测试：只有代理管理员才能升级合约。
     */
    function testUpgrade_Unauthorized_Reverts() public {
        // 尝试使用非管理员地址（卖家）升级合约
        vm.prank(seller);
        // 因为调用者不是管理员，交易预期会回滚
        vm.expectRevert("Ownable: caller is not the owner");
        
        // 这是一个强制类型转换，它告诉编译器将代理合约地址视为实现了 ITransparentUpgradeableProxy 的接口。
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(marketProxy)), address(marketImplV2), "0x");
    }
    
    /**
     * @notice 一个生成挂单 EIP-712 签名的辅助函数。
     */
    function getEIP712Signature(
        address signer,
        uint256 tokenId,
        uint256 price,
        uint256 nonce
    ) internal returns (bytes32, bytes memory) {
        // 编码类型化数据
        bytes32 listingTypehash = keccak256("Listing(uint256 tokenId,uint256 price,uint256 nonce)");
        bytes32 structuredDataHash = keccak256(abi.encode(
            listingTypehash,
            tokenId,
            price,
            nonce
        ));

        // 创建 EIP-712 域哈希
        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            // V2 合约初始化器中使用的名称和版本
            keccak256(bytes("NFTMarket_V2")),
            keccak256(bytes("1.0")),
            block.chainid,
            address(market)
        ));

        // 生成最终的摘要和签名
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structuredDataHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(uint160(signer)), digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        return (digest, signature);
    }
}
