// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// This is a corrected and simplified NFT for testing purposes.
contract MyNFT is ERC721URIStorage, Ownable {
    uint256 private _tokenIdCounter;

    constructor() ERC721("MockNFT", "MNFT") Ownable(msg.sender) {
        _tokenIdCounter = 0; // Initialize token ID counter
    }

    // Mint function to create new NFTs with sequential IDs
    function mint(address to, string memory uri) public onlyOwner returns (uint256) {
        uint256 newTokenId = _tokenIdCounter;
        _mint(to, newTokenId);
        _setTokenURI(newTokenId, uri);
        _tokenIdCounter++;
        return newTokenId;
    }

    // Getter for the next available token ID
    function currentTokenId() public view returns (uint256) {
        return _tokenIdCounter;
    }
}