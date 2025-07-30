// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol"; // 保持这一行

import "../src/NFTMarket.sol";
import "../src/MyNFT.sol";
import "../src/CloudToken.sol";



contract NFTMarketTest is Test {
    NFTMarket public market;
    MyNFT public mockNFT;
    CloudToken public mockToken;

    // Test accounts
    address public deployer;
    address public alice;
    address public bob;
    address public charlie;

    // Fixed NFT IDs for specific test cases
    uint256 internal constant ALICE_NFT_ID_0 = 0;
    uint256 internal constant ALICE_NFT_ID_1 = 1;

    // --- ONLY DECLARE THE ERC20 TRANSFER EVENT HERE ---
    // This definition is necessary for the `emit Transfer(...)` syntax used with ERC20 events.
    // The ERC721 Transfer will be handled by explicit topic matching.
    // You can keep other specific event declarations if needed for other tests
    // event Approval(address indexed owner, address indexed spender, uint256 value); // ERC20 Approval
    // event ApprovalForAll(address indexed owner, address indexed operator, bool approved); // ERC721 ApprovalForAll
    event ERC20Transfer(address indexed from, address indexed to, uint256 value); // ERC20 Transfer
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId); // ERC721 Transfer
    event Approval(address indexed owner, address indexed spender, uint256 value); // ERC20 Approval
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved); // ERC721 ApprovalForAll

    function setUp() public {
        deployer = vm.addr(1);
        alice = vm.addr(2);
        bob = vm.addr(3);
        charlie = vm.addr(4);

        vm.deal(deployer, 1 ether);
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        vm.deal(charlie, 1 ether);

        vm.startPrank(deployer);
        mockNFT = new MyNFT();
        mockToken = new CloudToken();
        market = new NFTMarket(address(mockNFT), address(mockToken));
        vm.stopPrank();

        vm.startPrank(deployer);
        mockNFT.mint(alice, "uri_alice_0");
        mockNFT.mint(alice, "uri_alice_1");
        vm.stopPrank();

        vm.startPrank(deployer);
        mockToken.mint(bob, 5000 * 10 ** mockToken.decimals());
        mockToken.mint(charlie, 10000 * 10 ** mockToken.decimals());
        vm.stopPrank();

        vm.startPrank(alice);
        mockNFT.setApprovalForAll(address(market), true);
        vm.stopPrank();

        vm.startPrank(bob);
        mockToken.approve(address(market), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(charlie);
        mockToken.approve(address(market), type(uint256).max);
        vm.stopPrank();
    }



    /// @dev Test successful listing of an NFT
    function testList_Success() public {
       uint256 tokenId = ALICE_NFT_ID_0;
        uint256 price = 100 ether;

        // Perform the transaction and record logs
        vm.startPrank(alice);
        vm.recordLogs(); // Start recording all events emitted
        market.list(tokenId, price);
        vm.stopPrank();

        // --- Manual Log Check for ERC721 Transfer event ---
        // Event: Transfer(address indexed from, address indexed to, uint256 indexed tokenId)
        bytes32 expectedTopic0 = keccak256("Transfer(address,address,uint256)"); // Event signature hash
        bytes32 expectedTopic1 = bytes32(uint256(uint160(alice)));             // indexed 'from' address
        bytes32 expectedTopic2 = bytes32(uint256(uint160(address(market))));   // indexed 'to' address
        bytes32 expectedTopic3 = bytes32(tokenId);                             // indexed 'tokenId'

        bool foundEvent = false;
        Vm.Log[] memory logs = vm.getRecordedLogs(); // Get all recorded logs

        for (uint i = 0; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            if (log.emitter == address(mockNFT) && // Event emitted by MyNFT
                log.topics.length == 4 &&           // 4 topics (signature + 3 indexed params)
                log.topics[0] == expectedTopic0 &&
                log.topics[1] == expectedTopic1 &&
                log.topics[2] == expectedTopic2 &&
                log.topics[3] == expectedTopic3)
            {
                foundEvent = true;
                break; // Found the event, no need to check further
            }
        }
        assertTrue(foundEvent, "ERC721 Transfer event not found or mismatched.");

        // ... (rest of your assertions) ...
        (uint256 listedPrice, address listedSeller) = market.listings(tokenId);
        NFTMarket.Listing memory listing = NFTMarket.Listing({price: listedPrice, seller: listedSeller});

        assertEq(listing.price, price, "Listing price mismatch");
        assertEq(listing.seller, alice, "Listing seller mismatch");
        assertEq(mockNFT.ownerOf(tokenId), address(market), "NFT not transferred to market");

    }

    /// @dev Test listing an NFT not owned by msg.sender
    function testList_Fail_NotOwner() public {
        uint256 tokenId = ALICE_NFT_ID_0;
        uint256 price = 100 ether;

        vm.startPrank(bob);
        vm.expectRevert("You must own the NFT");
        market.list(tokenId, price);
        vm.stopPrank();
    }

    /// @dev Test listing an NFT with zero price
    function testList_Fail_ZeroPrice() public {
        uint256 tokenId = ALICE_NFT_ID_0;
        uint256 price = 0;

        vm.startPrank(alice);
        vm.expectRevert("Price must be greater than zero");
        market.list(tokenId, price);
        vm.stopPrank();
    }

    /// @dev Test listing an NFT that is already with the market (implies already listed)
    function testList_Fail_AlreadyListed() public {
        uint256 tokenId = ALICE_NFT_ID_0;
        uint256 price = 100 ether;

        vm.startPrank(alice);
        market.list(tokenId, price);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert("You must own the NFT");
        market.list(tokenId, 200 ether);
        vm.stopPrank();
    }


    /// @dev Test successful NFT purchase
    function testBuyNFT_Success() public {
        uint256 tokenId = ALICE_NFT_ID_0;
        uint256 price = 50 ether;

        // Alice lists NFT
        vm.startPrank(alice);
        market.list(tokenId, price);
        vm.stopPrank();

        uint256 aliceInitialTokenBalance = mockToken.balanceOf(alice);
        uint256 bobInitialTokenBalance = mockToken.balanceOf(bob);

        // Perform the purchase transaction and record logs
        vm.startPrank(bob);
        vm.recordLogs(); // Start recording all events emitted
        market.buyNFT(tokenId);
        vm.stopPrank();

        Vm.Log[] memory logs = vm.getRecordedLogs(); // Get all recorded logs from this transaction

        // --- Manual Log Check for ERC20 Transfer event ---
        // Event: Transfer(address indexed from, address indexed to, uint256 value)
        bytes32 expectedERC20Topic0 = keccak256("Transfer(address,address,uint256)"); // Event signature hash
        bytes32 expectedERC20Topic1 = bytes32(uint256(uint160(bob)));               // indexed 'from' address
        bytes32 expectedERC20Topic2 = bytes32(uint256(uint160(alice)));             // indexed 'to' address
        bytes memory expectedERC20Data = abi.encode(price);                       // non-indexed 'value' parameter

        bool foundERC20Event = false;
        for (uint i = 0; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            // Check for emitter, topic 0, topic 1, topic 2, and the data part
            if (log.emitter == address(mockToken) && // Event emitted by MockCloudToken
                log.topics.length == 3 &&             // 3 topics (signature + 2 indexed params)
                log.topics[0] == expectedERC20Topic0 &&
                log.topics[1] == expectedERC20Topic1 &&
                log.topics[2] == expectedERC20Topic2 &&
                keccak256(log.data) == keccak256(expectedERC20Data)) // Compare the full data byte string
            {
                foundERC20Event = true;
                // Don't break, as there might be other logs we want to check later in the same loop
                // Or you can break if you only expect one match and process all logs in a single loop
                // For clarity here, we'll check the ERC721 event in a separate loop
                break; // Found ERC20, can break for this check
            }
        }
        assertTrue(foundERC20Event, "ERC20 Transfer event not found or mismatched.");

        // --- Manual Log Check for ERC721 Transfer event ---
        // Event: Transfer(address indexed from, address indexed to, uint256 indexed tokenId)
        bytes32 expectedERC721Topic0 = keccak256("Transfer(address,address,uint256)"); // Event signature hash
        bytes32 expectedERC721Topic1 = bytes32(uint256(uint160(address(market))));     // indexed 'from' address
        bytes32 expectedERC721Topic2 = bytes32(uint256(uint160(bob)));                 // indexed 'to' address
        bytes32 expectedERC721Topic3 = bytes32(tokenId);                               // indexed 'tokenId'

        bool foundERC721Event = false;
        // Iterate logs again (or continue from previous loop if you prefer)
        for (uint i = 0; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            if (log.emitter == address(mockNFT) && // Event emitted by MyNFT
                log.topics.length == 4 &&           // 4 topics (signature + 3 indexed params)
                log.topics[0] == expectedERC721Topic0 &&
                log.topics[1] == expectedERC721Topic1 &&
                log.topics[2] == expectedERC721Topic2 &&
                log.topics[3] == expectedERC721Topic3)
            {
                foundERC721Event = true;
                break; // Found ERC721, can break for this check
            }
        }
        assertTrue(foundERC721Event, "ERC721 Transfer event not found or mismatched.");


        // Assert token balances
        assertEq(mockToken.balanceOf(alice), aliceInitialTokenBalance + price, "Alice token balance incorrect");
        assertEq(mockToken.balanceOf(bob), bobInitialTokenBalance - price, "Bob token balance incorrect");

        // Assert NFT ownership
        assertEq(mockNFT.ownerOf(tokenId), bob, "NFT not transferred to Bob");

        // Assert listing cleared
        (uint256 clearedPrice, address clearedSeller) = market.listings(tokenId);
        NFTMarket.Listing memory clearedListing = NFTMarket.Listing({price: clearedPrice, seller: clearedSeller});
        assertEq(clearedListing.price, 0, "Listing price not cleared");
        assertEq(clearedListing.seller, address(0), "Listing seller not cleared");
    
    }

    /// @dev Test buying your own listed NFT
    function testBuyNFT_Fail_SelfPurchase() public {
        uint256 tokenId = ALICE_NFT_ID_0;
        uint256 price = 50 ether;

        vm.startPrank(alice);
        market.list(tokenId, price);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert("Cannot buy your own NFT");
        market.buyNFT(tokenId);
        vm.stopPrank();

        assertEq(mockNFT.ownerOf(tokenId), address(market), "NFT should remain with market");
        (uint256 currentPrice, ) = market.listings(tokenId);
        assertEq(currentPrice, price, "Listing should remain active");
    }

    /// @dev Test buying an NFT that was already purchased/delisted
    function testBuyNFT_Fail_AlreadyPurchased() public {
        uint256 tokenId = ALICE_NFT_ID_0;
        uint256 price = 50 ether;

        vm.startPrank(alice);
        market.list(tokenId, price);
        vm.stopPrank();

        vm.startPrank(bob);
        market.buyNFT(tokenId);
        vm.stopPrank();

        vm.startPrank(charlie);
        vm.expectRevert("This NFT is not for sale");
        market.buyNFT(tokenId);
        vm.stopPrank();
    }

    /// @dev Test `buyNFT` when the buyer has insufficient approval for the market
    function testBuyNFT_Fail_InsufficientAllowance() public {
        uint256 tokenId = ALICE_NFT_ID_0;
        uint256 price = 50 ether;
        uint256 approvedAmount = 10 ether;

        vm.startPrank(bob);
        mockToken.approve(address(market), approvedAmount);
        vm.stopPrank();

        vm.startPrank(alice);
        market.list(tokenId, price);
        vm.stopPrank();

        vm.startPrank(bob);
        // vm.expectRevert("ERC20: insufficient allowance");
        vm.expectRevert(abi.encodeWithSelector(
            IERC20Errors.ERC20InsufficientAllowance.selector,
            address(market),             // spender (from error log)
            approvedAmount,  // allowance (from error log, what was approved)
            price            // needed (from error log, what was required)
        ));
        market.buyNFT(tokenId);
        vm.stopPrank();

        assertEq(mockNFT.ownerOf(tokenId), address(market), "NFT should remain with market");
        (uint256 currentPrice, ) = market.listings(tokenId);
        assertEq(currentPrice, price, "Listing should remain active");
        assertEq(mockToken.allowance(bob, address(market)), approvedAmount, "Allowance should remain unchanged");
    }


    /// @dev Fuzz test for listing and buying with random prices and buyer addresses
    /// @param price_fuzz The price to list at (fuzzing from 0.01 to 10000 Token)
    /// @param buyer_fuzz The random address trying to buy
    function testFuzz_ListAndBuy(uint256 price_fuzz, address buyer_fuzz) public {
        uint256 tokenId = ALICE_NFT_ID_1;

        price_fuzz = bound(price_fuzz, 10 ** (mockToken.decimals() - 2), 10000 * 10 ** mockToken.decimals());

        vm.assume(mockNFT.ownerOf(tokenId) == alice || mockNFT.ownerOf(tokenId) == address(market));

        if (mockNFT.ownerOf(tokenId) == address(market)) {
            // Already listed, skip listing again.
        } else {
            vm.startPrank(alice);
            market.list(tokenId, price_fuzz);
            vm.stopPrank();
        }

        vm.assume(buyer_fuzz != alice && buyer_fuzz != address(0));

        vm.deal(buyer_fuzz, 1 ether);
        vm.startPrank(deployer);
        mockToken.mint(buyer_fuzz, price_fuzz + 1 ether);
        vm.stopPrank();

        vm.startPrank(buyer_fuzz);
        mockToken.approve(address(market), type(uint256).max);
        
        try market.buyNFT(tokenId) {
            assertEq(mockNFT.ownerOf(tokenId), buyer_fuzz, "NFT should be transferred to buyer on success");
            (uint256 clearedPrice, ) = market.listings(tokenId);
            assertEq(clearedPrice, 0, "Listing should be cleared on success");
        } catch Error(string memory reason) {
            bytes memory expectedRevertData_NotForSale = abi.encodePacked("This NFT is not for sale");
            bytes memory expectedRevertData_InsufficientBalance = abi.encodePacked("ERC20: transfer amount exceeds balance");
            bytes memory expectedRevertData_SelfPurchase = abi.encodePacked("Cannot buy your own NFT");
            bytes memory expectedRevertData_InsufficientAllowance = abi.encodePacked("ERC20: insufficient allowance");

            bool expectedRevert = (
                keccak256(abi.encodePacked(reason)) == keccak256(expectedRevertData_NotForSale) ||
                keccak256(abi.encodePacked(reason)) == keccak256(expectedRevertData_InsufficientBalance) ||
                keccak256(abi.encodePacked(reason)) == keccak256(expectedRevertData_SelfPurchase) ||
                keccak256(abi.encodePacked(reason)) == keccak256(expectedRevertData_InsufficientAllowance)
            );

            if (!expectedRevert) {
                revert(reason);
            }

            if (mockNFT.ownerOf(tokenId) == address(market)) {
                (uint256 currentPriceOnRevert, ) = market.listings(tokenId);
                assertEq(currentPriceOnRevert, price_fuzz, "Listing should remain active on expected revert");
            }
        }
        vm.stopPrank();
    }


    /// @dev Test that the NFTMarket contract never holds any payment tokens
    /// @param price_fuzz Fuzz test parameter for price
    // /// @param buyer_fuzz Fuzz test parameter for buyer address
    function testFuzz__invariant(uint256 price_fuzz, address buyer_fuzz) public {
        testFuzz_ListAndBuy(price_fuzz, buyer_fuzz);  
        assertEq(mockToken.balanceOf(address(market)), mockToken.balanceOf(address(market)), "NFTMarket contract should never hold payment tokens");
    }
}