// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol"; // Added for ecrecover if used directly
import "./RedToken.sol"; // Your custom RedToken, which inherits ERC20Permit
import "forge-std/console.sol"; // For debugging, can be removed in production

contract NFTMarket is Ownable {
    struct Listing {
        uint256 price;   // NFT price (in terms of paymentToken)
        address seller;  // Seller's address
    }

    IERC721 public nftContract;
    RedToken public paymentToken; // This is correctly typed as RedToken, which is an ERC20Permit

    // Stores listing information for each tokenId
    mapping(uint256 => Listing) public listings;

    // Whitelist of allowed buyers (project owner can add/remove users)
    mapping(address => bool) public whitelist;

    event List(address indexed seller, address indexed market, uint256 tokenId, uint256 price);
    event Buy(address indexed buyer, address indexed seller, uint256 tokenId, uint256 price);

    constructor(address _nftContract, address _paymentToken) Ownable(msg.sender) {
        nftContract = IERC721(_nftContract);
        paymentToken = RedToken(_paymentToken);
    }

    // Add an address to the whitelist
    function addToWhitelist(address _user) external onlyOwner {
        whitelist[_user] = true;
    }

    // Remove an address from the whitelist
    function removeFromWhitelist(address _user) external onlyOwner {
        whitelist[_user] = false;
    }

    // List an NFT for sale
    function list(uint256 tokenId, uint256 price) external {
        require(nftContract.ownerOf(tokenId) == msg.sender, "You must own the NFT");
        require(price > 0, "Price must be greater than zero");

        // The NFT is transferred to the market contract upon listing
        nftContract.transferFrom(msg.sender, address(this), tokenId);

        listings[tokenId] = Listing({
            price: price,
            seller: msg.sender
        });

        emit List(msg.sender, address(this), tokenId, price);
    }

    /// @notice Off-chain signed whitelist purchase using permit
    /// @dev This function now expects two sets of v,r,s parameters:
    ///      One for the whitelist signature (signed by owner), and one for the ERC20 Permit (signed by buyer).
    function permitBuy(
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        uint8 _wlV,     // Whitelist signature: v parameter
        bytes32 _wlR,   // Whitelist signature: r parameter
        bytes32 _wlS,   // Whitelist signature: s parameter
        uint8 _permitV, // ERC20 Permit signature: v parameter
        bytes32 _permitR, // ERC20 Permit signature: r parameter
        bytes32 _permitS  // ERC20 Permit signature: s parameter
    ) external {
        require(block.timestamp <= deadline, "Signature expired");

        Listing memory listing = listings[tokenId];
        require(listing.price == price, "Incorrect price");
        require(listing.seller != address(0), "Token not listed");
        require(msg.sender != listing.seller, "Cannot buy your own NFT");

        // --- 1. Verify the Whitelist Signature (signed by the NFTMarket owner) ---
        // Reconstruct the message hash that the owner signed for the whitelist
        // This hash must match exactly what was signed off-chain by the owner.
        bytes32 whitelistMessageHash = keccak256(abi.encodePacked(msg.sender, tokenId, price, deadline));
        // Apply the Ethereum signed message prefix
        bytes32 ethSignedWhitelistHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", whitelistMessageHash));

        // Recover the signer address using the whitelist signature parameters
        address recoveredWhitelistSigner = ECDSA.recover(ethSignedWhitelistHash, _wlV, _wlR, _wlS);
        console.log("Recovered whitelist signer:", recoveredWhitelistSigner); // For debugging
        require(recoveredWhitelistSigner == owner(), "Invalid whitelist signature: not signed by owner");

        // --- 2. Verify Buyer Whitelist Status (separate check) ---
        // This check confirms the buyer was added to the whitelist through the `addToWhitelist` function.
        // The owner's signature serves as the "permit" for the buyer to purchase, but the buyer still needs
        // to be explicitly whitelisted if your contract design requires it.
        require(whitelist[msg.sender], "Buyer is not whitelisted");

        // --- 3. Use ERC20 Permit for Token Transfer Authorization (signed by msg.sender/buyer) ---
        // This line calls the `permit` function on the RedToken contract.
        // The RedToken contract (which inherits ERC20Permit) will internally verify
        // that the `_permitV, _permitR, _permitS` are a valid signature from `msg.sender`
        // for the specified `price`, `deadline`, and the current `nonce` of `msg.sender`.
        paymentToken.permit(
            msg.sender,      // The owner of the tokens (buyer's address)
            address(this),   // The spender (NFTMarket contract)
            price,           // The amount of tokens approved
            deadline,        // The deadline for the permit to be valid
            _permitV, _permitR, _permitS // The buyer's signature for the permit
        );

        // --- 4. Execute Token Transfer (from buyer to seller) ---
        // The `permit` call above effectively acts as an `approve` call.
        // Now, we can safely call `transferFrom` as the market contract is approved.
        require(paymentToken.transferFrom(msg.sender, listing.seller, price), "Payment failed: token transfer");

        // --- 5. Transfer NFT (from market to buyer) ---
        nftContract.transferFrom(address(this), msg.sender, tokenId);

        // --- 6. Clean up Listing ---
        delete listings[tokenId];

        emit Buy(msg.sender, listing.seller, tokenId, price);
    }
}