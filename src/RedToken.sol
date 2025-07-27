// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract RedToken is ERC20Permit {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {}

    // Mint function for testing purpose
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

}
