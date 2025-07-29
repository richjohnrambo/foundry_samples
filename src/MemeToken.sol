// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";

contract MemeToken is ERC20 {
    address public issuer; // Meme 发行者
    uint public totalSupplyLimit; // 总供应量限制
    uint public perMint; // 每次铸造数量
    uint public price; // 每个 Meme 铸造的费用（以 wei 为单位）
    uint public currentSupply; // 当前已铸造的 Meme 数量
    address public platformOwner; // 项目方（平台）地址

    constructor(
        string memory symbol,
        uint _totalSupply,
        uint _perMint,
        uint _price,
        address _issuer,
        address _platformOwner
    ) ERC20("Meme Token", symbol) {
        issuer = _issuer;
        platformOwner = _platformOwner;
        totalSupplyLimit = _totalSupply;
        perMint = _perMint;
        price = _price;

        // 初始铸造一定数量的 Meme 给发行者
        _mint(_issuer, _totalSupply);
    }

    // 用户铸造 Meme
    function mint(address to, uint amount) external payable {
        require(amount == perMint, "Can only mint perMint amount");
        require(msg.value == price * amount, "Incorrect fee");

        // 确保铸造的 Meme 不超过总供应量
        require(currentSupply + amount <= totalSupplyLimit, "Exceeds total supply");

        // 1% 收费给项目方
        uint fee = msg.value / 100;
        
        // // 将 1% 的费用转给项目方
        // payable(platformOwner).sendValue(fee);
        // console.log("Minting", amount, "Meme to", to);
        // // 将剩余费用转给 Meme 发行者
        // payable(issuer).sendValue(msg.value - fee);

        // 安全转账：项目方
        (bool sentToPlatform, ) = payable(platformOwner).call{value: fee}("");
        require(sentToPlatform, "Failed to send fee to platform");
console.log("Minting", amount, "Meme to", to);
        // 安全转账：发行者
        (bool sentToIssuer, ) = payable(issuer).call{value: msg.value - fee}("");
        require(sentToIssuer, "Failed to send payment to issuer");
            
        // 铸造 Meme
        _mint(to, amount);
        currentSupply += amount;
    }


}
