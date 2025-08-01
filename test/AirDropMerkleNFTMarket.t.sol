// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/AirdropMerkleNFTMarket.sol";
import "../src/RedToken.sol";
import "../src/MyNFT.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AirdropMerkleNFTMarketTest is Test {
    AirdropMerkleNFTMarket market;
    RedToken redToken;
    MyNFT myNFT;

    // 重新声明事件以供 vm.expectEmit(...) 使用
    event NFTListed(uint256 indexed nftId, address indexed seller, uint256 price);
    event NFTClaimed(
        address indexed buyer, 
        uint256 indexed nftId, 
        uint256 originalPrice, 
        uint256 discountedPrice
    );
    event MerkleRootUpdated(bytes32 oldRoot, bytes32 newRoot);
    
    address deployer = makeAddr("deployer");
    address alice;
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address david = makeAddr("david"); // Not in whitelist
    uint256 alicePrivateKey;

    bytes32 public root;
    bytes32[] private proofAlice;
    bytes32[] private proofBob;
    bytes32[] private proofCharlie;

    // 根据 MyNFT 的 mint 行为，硬编码 NFT ID
    uint256 public constant NFT_ID_1 = 0;
    uint256 public constant NFT_ID_2 = 1;
    uint256 public constant NFT_PRICE = 1000 ether;
    uint256 public constant DISCOUNTED_PRICE = NFT_PRICE / 2;

    function setUp() public {
        vm.startPrank(deployer);

         (alice, alicePrivateKey) = makeAddrAndKey("alice");

        redToken = new RedToken("Red Token", "RED");
        myNFT = new MyNFT();

        // Mint some initial tokens for test accounts
        redToken.mint(alice, 10000 ether);
        redToken.mint(bob, 10000 ether);
        redToken.mint(charlie, 10000 ether);

        // --- 修正后的 Merkle 树设置：动态生成证明以避免排序错误 ---
        bytes32 leafAlice = keccak256(abi.encodePacked(alice));
        bytes32 leafBob = keccak256(abi.encodePacked(bob));
        bytes32 leafCharlie = keccak256(abi.encodePacked(charlie));
        
        bytes32[] memory sortedLeaves = new bytes32[](3);
        sortedLeaves[0] = leafAlice;
        sortedLeaves[1] = leafBob;
        sortedLeaves[2] = leafCharlie;
        
        for (uint i = 0; i < sortedLeaves.length - 1; i++) {
            for (uint j = i + 1; j < sortedLeaves.length; j++) {
                if (sortedLeaves[i] > sortedLeaves[j]) {
                    bytes32 temp = sortedLeaves[i];
                    sortedLeaves[i] = sortedLeaves[j];
                    sortedLeaves[j] = temp;
                }
            }
        }
        
        // 构建 Merkle 根
        bytes32 node1 = keccak256(abi.encodePacked(sortedLeaves[0], sortedLeaves[1]));
        bytes32 node2 = sortedLeaves[2];
        
        if (node1 > node2) {
            bytes32 temp = node1;
            node1 = node2;
            node2 = temp;
        }

        root = keccak256(abi.encodePacked(node1, node2));

        // 根据实际排序后的叶子节点位置，动态生成 Merkle 证明
        if (sortedLeaves[0] == leafAlice) {
            proofAlice = new bytes32[](2);
            proofAlice[0] = sortedLeaves[1];
            proofAlice[1] = sortedLeaves[2];
        } else if (sortedLeaves[1] == leafAlice) {
            proofAlice = new bytes32[](2);
            proofAlice[0] = sortedLeaves[0];
            proofAlice[1] = sortedLeaves[2];
        } else {
            proofAlice = new bytes32[](1);
            proofAlice[0] = keccak256(abi.encodePacked(sortedLeaves[0], sortedLeaves[1]));
        }

        if (sortedLeaves[0] == leafBob) {
            proofBob = new bytes32[](2);
            proofBob[0] = sortedLeaves[1];
            proofBob[1] = sortedLeaves[2];
        } else if (sortedLeaves[1] == leafBob) {
            proofBob = new bytes32[](2);
            proofBob[0] = sortedLeaves[0];
            proofBob[1] = sortedLeaves[2];
        } else {
            proofBob = new bytes32[](1);
            proofBob[0] = keccak256(abi.encodePacked(sortedLeaves[0], sortedLeaves[1]));
        }

        if (sortedLeaves[0] == leafCharlie) {
            proofCharlie = new bytes32[](2);
            proofCharlie[0] = sortedLeaves[1];
            proofCharlie[1] = sortedLeaves[2];
        } else if (sortedLeaves[1] == leafCharlie) {
            proofCharlie = new bytes32[](2);
            proofCharlie[0] = sortedLeaves[0];
            proofCharlie[1] = sortedLeaves[2];
        } else {
            proofCharlie = new bytes32[](1);
            proofCharlie[0] = keccak256(abi.encodePacked(sortedLeaves[0], sortedLeaves[1]));
        }

        market = new AirdropMerkleNFTMarket(address(redToken), address(myNFT), root, deployer);

        myNFT.mint(deployer, "ipfs://nft_uri_1");
        myNFT.approve(address(market), NFT_ID_1); 

        myNFT.mint(deployer, "ipfs://nft_uri_2");
        myNFT.approve(address(market), NFT_ID_2); 

        vm.stopPrank();
    }

    // --- NFT Listing Tests ---

    function testListNFT_Success() public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit NFTListed(NFT_ID_1, deployer, NFT_PRICE);
        market.listNFT(NFT_ID_1, NFT_PRICE);
        vm.stopPrank();

        AirdropMerkleNFTMarket.NFTListing memory listing = market.getNFTListing(NFT_ID_1);
        assertEq(listing.seller, deployer);
        assertEq(listing.price, NFT_PRICE);
        assertTrue(listing.isActive);
    }

    function testListNFT_NotNFTOwnerReverts() public {
        vm.startPrank(alice);
        vm.expectRevert("Not NFT owner");
        market.listNFT(NFT_ID_1, NFT_PRICE);
        vm.stopPrank();
    }

    function testListNFT_PriceZeroReverts() public {
        vm.startPrank(deployer);
        vm.expectRevert("Price must be greater than 0");
        market.listNFT(NFT_ID_1, 0);
        vm.stopPrank();
    }

    // --- Claim NFT Tests ---

    function testClaimNFT_Success_Alice() public {
        vm.startPrank(deployer);
        market.listNFT(NFT_ID_1, NFT_PRICE);
        vm.stopPrank();

        vm.startPrank(alice);
        redToken.approve(address(market), DISCOUNTED_PRICE);
        
        uint256 initialAliceBalance = redToken.balanceOf(alice);
        uint256 initialDeployerBalance = redToken.balanceOf(deployer);

        vm.expectEmit(true, true, true, false);
        emit NFTClaimed(alice, NFT_ID_1, NFT_PRICE, DISCOUNTED_PRICE);
        market.claimNFT(proofAlice, NFT_ID_1);

        assertEq(redToken.balanceOf(alice), initialAliceBalance - DISCOUNTED_PRICE);
        assertEq(redToken.balanceOf(deployer), initialDeployerBalance + DISCOUNTED_PRICE);
        assertEq(myNFT.ownerOf(NFT_ID_1), alice);

        AirdropMerkleNFTMarket.NFTListing memory listing = market.getNFTListing(NFT_ID_1);
        assertFalse(listing.isActive);
        assertTrue(market.hasClaimed(alice));
        vm.stopPrank();
    }

    function testClaimNFT_AlreadyClaimedReverts() public {
        vm.startPrank(deployer);
        market.listNFT(NFT_ID_1, NFT_PRICE);
        vm.stopPrank();

        vm.startPrank(alice);
        redToken.approve(address(market), DISCOUNTED_PRICE);
        market.claimNFT(proofAlice, NFT_ID_1);

        vm.expectRevert(AirdropMerkleNFTMarket.AlreadyClaimed.selector);
        market.claimNFT(proofAlice, NFT_ID_1);
        vm.stopPrank();
    }

    function testClaimNFT_NotInWhitelistReverts() public {
        vm.startPrank(deployer);
        market.listNFT(NFT_ID_1, NFT_PRICE);
        vm.stopPrank();

        vm.startPrank(david);
        redToken.approve(address(market), DISCOUNTED_PRICE);
        vm.expectRevert(AirdropMerkleNFTMarket.NotInWhitelist.selector);
        market.claimNFT(proofAlice, NFT_ID_1);
        vm.stopPrank();
    }

    function testClaimNFT_NFTNotListedReverts() public {
        vm.startPrank(alice);
        redToken.approve(address(market), DISCOUNTED_PRICE);
        vm.expectRevert(AirdropMerkleNFTMarket.NFTNotListed.selector);
        market.claimNFT(proofAlice, 999);
        vm.stopPrank();
    }

    function testClaimNFT_NFTNotActiveReverts() public {
        vm.startPrank(deployer);
        market.listNFT(NFT_ID_1, NFT_PRICE);
        vm.stopPrank();

        vm.startPrank(alice);
        redToken.approve(address(market), DISCOUNTED_PRICE);
        market.claimNFT(proofAlice, NFT_ID_1);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(AirdropMerkleNFTMarket.NFTNotActive.selector);
        market.claimNFT(proofBob, NFT_ID_1);
        vm.stopPrank();
    }


    function testClaimNFT_InsufficientBalanceReverts() public {
        vm.startPrank(deployer);
        market.listNFT(NFT_ID_1, NFT_PRICE);
        vm.stopPrank();

        vm.startPrank(charlie);
        // 首先，将 charlie 的代币余额降至低于折扣价
        redToken.transfer(david, redToken.balanceOf(charlie) - (DISCOUNTED_PRICE - 1));
        
        // 批准足额的代币，以确保不是 allowance 的问题
        redToken.approve(address(market), DISCOUNTED_PRICE); 
        
        // 期望在 transferFrom 时因为余额不足而 revert
        vm.expectRevert("Insufficient balance");
        
        // 传入正确的证明，以便通过白名单验证
        market.claimNFT(proofCharlie, NFT_ID_1);
        vm.stopPrank();
    }


    // --- Permit Pre-Pay Tests ---
    function testPermitPrePay_Success() public {
        vm.startPrank(alice);
        uint256 value = 100 ether;
        uint256 deadline = block.timestamp + 1000;

        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            alice,
            address(market),
            value,
            redToken.nonces(alice),
            deadline
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            redToken.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        market.permitPrePay(value, deadline, v, r, s);

        assertEq(redToken.allowance(alice, address(market)), value);
        vm.stopPrank();
    }

    // --- Admin Function Tests ---

    function testUpdateMerkleRoot_Success() public {
        bytes32 newRoot = keccak256(abi.encodePacked("new_merkle_root"));

        vm.startPrank(deployer);
        vm.expectEmit(true, true, false, false);
        emit MerkleRootUpdated(root, newRoot);
        market.updateMerkleRoot(newRoot);
        vm.stopPrank();

        assertEq(market.merkleRoot(), newRoot);
    }

    function testUpdateMerkleRoot_NotOwnerReverts() public {
        bytes32 newRoot = keccak256(abi.encodePacked("new_merkle_root"));

        vm.startPrank(alice);
        bytes memory expectedRevert = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice);
        vm.expectRevert(expectedRevert);
        market.updateMerkleRoot(newRoot);
        vm.stopPrank();
    }

    // --- Query Function Tests ---

    function testGetNFTListing_Existing() public {
        vm.startPrank(deployer);
        market.listNFT(NFT_ID_1, NFT_PRICE);
        vm.stopPrank();

        AirdropMerkleNFTMarket.NFTListing memory listing = market.getNFTListing(NFT_ID_1);
        assertEq(listing.seller, deployer);
        assertEq(listing.price, NFT_PRICE);
        assertTrue(listing.isActive);
    }

    function testGetNFTListing_NonExisting() public {
        AirdropMerkleNFTMarket.NFTListing memory listing = market.getNFTListing(999);
        assertEq(listing.seller, address(0));
        assertEq(listing.price, 0);
        assertFalse(listing.isActive);
    }

    function testVerifyWhitelist_True() public {
        assertTrue(market.verifyWhitelist(alice, proofAlice));
    }

    function testVerifyWhitelist_False() public {
        assertFalse(market.verifyWhitelist(david, proofAlice));
        bytes32[] memory invalidProof;
        assertFalse(market.verifyWhitelist(alice, invalidProof));
    }

     function testMulticall_PermitAndClaim_Success() public {
        // Step 1: Deployer lists an NFT
        vm.startPrank(deployer);
        market.listNFT(NFT_ID_1, NFT_PRICE);
        vm.stopPrank();
        
        // Step 2: Alice prepares a permit and claim
        vm.startPrank(alice);
        
        // Prepare parameters for permitPrePay
        uint256 value = DISCOUNTED_PRICE;
        uint256 deadline = block.timestamp + 1000;
        
        // Generate signature for permitPrePay
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            alice,
            address(market),
            value,
            redToken.nonces(alice),
            deadline
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            redToken.DOMAIN_SEPARATOR(),
            structHash
        ));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);
        
        // Step 3: Encode the function calls
        // Encode the permitPrePay call
        bytes memory permitCallData = abi.encodeWithSelector(
            market.permitPrePay.selector, 
            value, 
            deadline, 
            v, 
            r, 
            s
        );
        
        // Encode the claimNFT call
        bytes memory claimCallData = abi.encodeWithSelector(
            market.claimNFT.selector, 
            proofAlice, 
            NFT_ID_1
        );
        
        // Step 4: Create a multicall array
        bytes[] memory calls = new bytes[](2);
        calls[0] = permitCallData;
        calls[1] = claimCallData;
        
        // Step 5: Execute multicall and check state changes
        uint256 initialAliceBalance = redToken.balanceOf(alice);
        uint256 initialDeployerBalance = redToken.balanceOf(deployer);
        
        // Execute the multicall (a mock function in the test contract for demonstration)
        // Note: The multicall function itself should be added to your main AirdropMerkleNFTMarket contract
        // This is a simplified test implementation for demonstration purposes.
        for (uint i = 0; i < calls.length; i++) {
            // Here we use a low-level call to the market contract with the encoded data
            (bool success, ) = address(market).call(calls[i]);
            require(success, "Multicall failed");
        }

        // Step 6: Assert the final state
        assertEq(redToken.allowance(alice, address(market)), 0, "Allowance should be used");
        assertEq(redToken.balanceOf(alice), initialAliceBalance - DISCOUNTED_PRICE, "Alice's balance is incorrect");
        assertEq(redToken.balanceOf(deployer), initialDeployerBalance + DISCOUNTED_PRICE, "Deployer's balance is incorrect");
        assertEq(myNFT.ownerOf(NFT_ID_1), alice, "NFT owner is incorrect");

        AirdropMerkleNFTMarket.NFTListing memory listing = market.getNFTListing(NFT_ID_1);
        assertFalse(listing.isActive, "NFT should no longer be listed");
        assertTrue(market.hasClaimed(alice), "Alice should be marked as claimed");

        vm.stopPrank();
    }
}