// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// This is a correct implementation using OpenZeppelin's ERC20.
// It fully supports transferFrom which your NFTMarket needs for payments.
contract CloudToken is ERC20, Ownable {
    constructor() ERC20("MockCloudToken", "MCT") Ownable(msg.sender) {
        // Initial mint to the deployer using OpenZeppelin's _mint
        _mint(msg.sender, 1_000_000 * 10 ** decimals()); // 1,000,000 tokens
    }

    // A simple mint function for testing purposes, callable by the owner
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}