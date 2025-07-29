// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MemeToken.sol";  // 导入 MemeToken 合约

contract MemeFactory {
    address public owner;

    // 存储已部署的 Meme 代币地址
    mapping(address => address) public memeTokens;

    constructor() {
        owner = msg.sender;
    }

    // 部署 Meme 合约
    // 部署 Meme 合约，现在可以指定 MemeToken 的发行者和平台方
    function deployMeme(
        string memory symbol,
        uint totalSupply,
        uint perMint,
        uint price,
        address _tokenIssuer,      // MemeToken 的发行者
        address _tokenPlatformOwner // MemeToken 的平台方
    ) public returns (address) {
        MemeToken newMemeToken = new MemeToken(
            symbol,
            totalSupply,
            perMint,
            price,
            _tokenIssuer,       // 使用传入的 _tokenIssuer
            _tokenPlatformOwner // 使用传入的 _tokenPlatformOwner
        );
        memeTokens[_tokenIssuer] = address(newMemeToken); // 将 MemeToken 合约地址与指定发行者关联
        return address(newMemeToken);
    }

    // 用户铸造 Meme
    function mintMeme(address tokenAddr) public payable {
        MemeToken memeToken = MemeToken(tokenAddr);

        // 确保用户支付了正确的费用
        uint requiredFee = memeToken.price() * memeToken.perMint();
        require(msg.value == requiredFee, "Incorrect fee");

        // 每次铸造的数量不能超过 perMint
        uint perMint = memeToken.perMint();
        memeToken.mint{value: msg.value}(msg.sender, perMint);
    }

    // 获取 MemeToken 合约地址
    function getMemeToken(address user) public view returns (address) {
        return memeTokens[user];
    }

    
}
