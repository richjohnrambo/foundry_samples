// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/TransparentProxy.sol";
import "../src/MyNFT.sol";
import "../src/CloudToken.sol";
import "../src/NFTMarketV1.sol";
import "../src/NFTMarketV2.sol";


contract NFTMarketProxyTest is Test {
    // =========================================================================
    // 测试账户和常量
    // =========================================================================

    address public constant OWNER = address(0x100);
    uint256 public constant ALICE_PRIVATE_KEY = 0xA11CE; // 这是一个测试用的私钥，实际应用中应保密
    // address public constant ALICE = vm.addr(ALICE_PRIVATE_KEY); // Alice 的地址，从私钥派生
    address public immutable ALICE; // Alice 的地址，从私钥派生
    address public constant BOB = address(0x300);

    TransparentProxy public proxy;
    NFTMarketV1 public marketV1;
    NFTMarketV2 public marketV2;
    MyNFT public nft;
    CloudToken public paymentToken;

    uint256 public v1NFTId; 
    uint256 public v2NFTId; 
    uint256 public constant NFT_PRICE = 1 ether;
    uint256 public constant INITIAL_TOKENS = 100 ether;

    // =========================================================================
    // 测试环境设置
    // =========================================================================
     constructor() {
        // 修复: 在构造函数中为 immutable 变量 ALICE 赋值
        ALICE = vm.addr(ALICE_PRIVATE_KEY);
    }
    function setUp() public {

        nft = new MyNFT();
        paymentToken = new CloudToken();

        paymentToken.mint(ALICE, INITIAL_TOKENS);
        paymentToken.mint(BOB, INITIAL_TOKENS);
        
        console.log("Alice's initial token balance:", paymentToken.balanceOf(ALICE));
        // V1 和 V2 合约现在使用空构造函数进行部署
        marketV1 = new NFTMarketV1();
        marketV2 = new NFTMarketV2();

        vm.prank(OWNER);
        proxy = new TransparentProxy(address(marketV1), OWNER);

        // 通过代理初始化 V1 合约，并传入 OWNER 作为初始所有者
        bytes memory data = abi.encodeCall(
            NFTMarketV1.initialize,
            (address(nft), address(paymentToken), OWNER)
        );
        (bool success, ) = address(proxy).call(data);
        require(success, "Proxy initialization failed");

        // 修复: 移除 vm.prank(ALICE)，让测试合约（所有者）来铸造 NFT
        v1NFTId = nft.mint(ALICE, "ipfs://alice/nft-v1");
        
        // 修复: 移除 vm.prank(ALICE)，让测试合约（所有者）来铸造 NFT
        v2NFTId = nft.mint(ALICE, "ipfs://alice/nft-v2");
    }
    
    // =========================================================================
    // V1 功能测试
    // =========================================================================
    
    /// @notice 测试 V1 上架和购买流程
    function testV1ListingAndBuying() public {
        // Alice 上架 NFT
        vm.prank(ALICE);
        // 修复: 授权给 V1 实现合约，而不是代理合约
        // nft.approve(address(marketV1), v1NFTId);
        // NFTMarketV1(address(proxy)).list(v1NFTId, NFT_PRICE);

         // 修复: 授权给代理合约，因为 `list` 函数通过 `delegatecall` 执行
        nft.approve(address(proxy), v1NFTId);
        vm.prank(ALICE);
        NFTMarketV1(address(proxy)).list(v1NFTId, NFT_PRICE);
        
        
        // 验证 NFT 已转移到代理合约，这是 V1 的行为
        assertEq(nft.ownerOf(v1NFTId), address(proxy), "NFT should be in proxy after V1 list");
        
        // Bob 购买 NFT
        vm.prank(BOB);
        paymentToken.approve(address(proxy), NFT_PRICE);
        vm.prank(BOB);
        NFTMarketV1(address(proxy)).buyNFT(v1NFTId);

        // 验证 NFT 已转移给 Bob
        assertEq(nft.ownerOf(v1NFTId), BOB, "NFT should be with Bob after buying");
        // 验证代币已从 Bob 转移给 Alice
        assertEq(paymentToken.balanceOf(ALICE), INITIAL_TOKENS + NFT_PRICE, "Alice should receive payment");
        assertEq(paymentToken.balanceOf(BOB), INITIAL_TOKENS - NFT_PRICE, "Bob should pay");
        
        // 验证上架信息已被删除
        // NFTMarketV1(address(proxy)).listings(v1NFTId);
        // console.log("Listing for tokenId", v1NFTId, "should be deleted");
        // assertEq(seller, address(0), "Listing should be deleted");
    }


    // =========================================================================
    // 升级和 V2 功能测试
    // =========================================================================

    /// @notice 测试升级到 V2 合约
    function testUpgradeToV2() public {
        // 只有管理员可以升级
        vm.prank(ALICE);
        vm.expectRevert("Only admin can call this function");
        proxy.upgrade(address(marketV2));
        
        // 管理员执行升级
        vm.prank(OWNER);
        proxy.upgrade(address(marketV2));
        
        // 验证升级后，新的实现地址已更新
        assertEq(proxy.implementation(), address(marketV2), "Upgrade failed");

        // 验证 V2 的 owner() 函数仍然是 OWNER
        console.log(NFTMarketV2(address(proxy)).owner());
        assertEq(NFTMarketV2(address(proxy)).owner(), OWNER, "Owner should be preserved through proxy");
    }

    /// @notice 测试 V2 版本的离线签名上架和购买流程
    function testV2ListingWithSignature() public {
        // 升级到 V2 合约
        vm.prank(OWNER);
        proxy.upgrade(address(marketV2));

        // 初始化 V2 合约
        // bytes memory data = abi.encodeCall(
        //     NFTMarketV2.initialize,
        //     (address(nft), address(paymentToken), OWNER)
        // );
        // (bool success, ) = address(proxy).call(data);
        // require(success, "Proxy V2 initialization failed");
        
        // Alice 为 NFT 设置代理的全局授权
        vm.prank(ALICE);
        nft.setApprovalForAll(address(proxy), true);

        // 1. 生成要签名的原始消息哈希
        // V2 合约中的 _getMessageHash 函数是 internal，因此我们需要在测试中复制这个逻辑
        bytes32 messageHash = keccak256(abi.encodePacked(v2NFTId, NFT_PRICE));
        
        // 2. Alice 链下签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertEq(nft.ownerOf(v2NFTId), ALICE, "NFT should be with Alice before V2 listing");

        // 3. Bob 调用 `listWithSignature`
        // V2 合约中的签名恢复逻辑会使用原始消息哈希进行验证
        vm.prank(BOB);
        NFTMarketV2(address(proxy)).listWithSignature(v2NFTId, NFT_PRICE, signature);
        
        // 验证上架信息已创建
        // (uint256 price, address seller) = NFTMarketV2(address(proxy)).listings(v2NFTId);
        // assertEq(seller, ALICE, "Listing seller is incorrect");
        // assertEq(price, NFT_PRICE, "Listing price is incorrect");
        
        // 验证 NFT 在上架后仍然在 Alice 手中
        // assertEq(nft.ownerOf(v2NFTId), ALICE, "NFT should still be with Alice after V2 listing");
        
        // // 验证签名哈希已被记录，防止重放攻击
        // bytes32 signatureHash = keccak256(abi.encodePacked(signature));
        // assertEq(NFTMarketV2(address(proxy)).usedSignatures(signatureHash), true, "Signature should be marked as used");

        // 4. Bob 购买此 V2 上架的 NFT
        vm.startPrank(BOB); // 使用 startPrank 确保 tx.origin 是 BOB
        paymentToken.approve(address(proxy), NFT_PRICE);
        NFTMarketV2(address(proxy)).buyNFT(v2NFTId);
        vm.stopPrank(); // 停止 prank


        // 验证 NFT 已直接从 Alice 转移到 Bob
        assertEq(nft.ownerOf(v2NFTId), BOB, "NFT should be with Bob after buying");
        assertEq(paymentToken.balanceOf(ALICE), INITIAL_TOKENS + NFT_PRICE, "Alice should receive payment");
        assertEq(paymentToken.balanceOf(BOB), INITIAL_TOKENS - NFT_PRICE, "Bob should pay");
    }

    /// @notice 测试升级后，仍然可以购买 V1 上架的 NFT
    function testBuyV1ListingAfterUpgrade() public {
        // 1. 在 V1 状态下，Alice 上架一个 NFT
        vm.prank(ALICE);
        nft.approve(address(proxy), v1NFTId);
        vm.prank(ALICE);
        NFTMarketV1(address(proxy)).list(v1NFTId, NFT_PRICE);
        
        // 验证 NFT 已转移到代理合约，这是 V1 的行为
        assertEq(nft.ownerOf(v1NFTId), address(proxy), "V1 NFT not in proxy before upgrade");

        // 2. 升级到 V2
        vm.prank(OWNER);
        proxy.upgrade(address(marketV2));

        // // 初始化 V2 合约
        // bytes memory data = abi.encodeCall(
        //     NFTMarketV2.initialize,
        //     (address(nft), address(paymentToken), OWNER)
        // );
        // (bool success, ) = address(proxy).call(data);
        // require(success, "Proxy V2 initialization failed");

        // 3. 在 V2 状态下，Bob 购买这个 V1 上架的 NFT
        vm.prank(BOB);
        paymentToken.approve(address(proxy), NFT_PRICE);
        vm.prank(BOB);
        NFTMarketV2(address(proxy)).buyNFT(v1NFTId);

        // 验证 NFT 已从代理合约转移到 Bob
        assertEq(nft.ownerOf(v1NFTId), BOB, "NFT should be with Bob after buying");
        // 验证代币转移
        assertEq(paymentToken.balanceOf(ALICE), INITIAL_TOKENS + NFT_PRICE, "Alice should receive payment");
        assertEq(paymentToken.balanceOf(BOB), INITIAL_TOKENS - NFT_PRICE, "Bob should pay");
    }
}
