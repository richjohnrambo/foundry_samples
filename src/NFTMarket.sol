// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// IMPORTANT: Ensure this import path is correct. If your CloudToken is in src/, use "./CloudToken.sol".
// If you're using the mock, you'll import MockCloudToken in your test file instead.
import "./CloudToken.sol";



contract NFTMarket is Ownable {
    // Used to store listed NFT information
    struct Listing {
        uint256 price;   // NFT price (in terms of paymentToken)
        address seller;  // Seller's address
    }

    // NFT contract address
    IERC721 public nftContract;
    // ERC-20 token contract address used for payments
    CloudToken public paymentToken; // Type-hinting with CloudToken is fine here

    // Stores listing information for each tokenId
    mapping(uint256 => Listing) public listings;

    event List(address indexed from, address indexed to, uint256 value);
    event Buy(address indexed owner, address indexed spender, uint256 value);

    constructor(address _nftContract, address _paymentToken) Ownable(msg.sender) {
        nftContract = IERC721(_nftContract);
        paymentToken = CloudToken(_paymentToken);
    }

    // List an NFT for sale
    function list(uint256 tokenId, uint256 price) external {
        require(nftContract.ownerOf(tokenId) == msg.sender, "You must own the NFT");
        require(price > 0, "Price must be greater than zero");

        // The seller must have approved the market contract to transfer their NFT
        // prior to calling this function.
        nftContract.transferFrom(msg.sender, address(this), tokenId); // Transfers NFT to the market contract

        listings[tokenId] = Listing({
            price: price,
            seller: msg.sender
        });
        emit List(msg.sender, address(this), price);

    }

    // Buy an NFT
    function buyNFT(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];
        require(listing.price > 0, "This NFT is not for sale"); // Checks if it's listed

        uint256 price = listing.price;
        address seller = listing.seller;

        // Prevent self-purchase
        require(msg.sender != seller, "Cannot buy your own NFT");

        // Transfer tokens from buyer to seller.
        // This relies on the buyer having approved the market contract to spend their tokens.
        require(paymentToken.transferFrom(msg.sender, seller, price), "Payment failed");

        // Transfer NFT from market to buyer
        nftContract.transferFrom(address(this), msg.sender, tokenId);

        // Clear the listing information
        delete listings[tokenId];
        emit Buy(seller, msg.sender, price);
    }
}
