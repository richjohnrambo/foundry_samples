// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol"; // For minimal proxies (EIP-1167)
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // For casting to ERC20

import "./MemeToken.sol"; // 导入 MemeToken 合约

contract MemeFactory is Ownable {
    using Clones for address; // 启用 Clones 库的扩展功能

    address public immutable MEME_TOKEN_IMPLEMENTATION; // MemeToken 的实现合约地址

    // 存储每个部署的 MemeToken 合约实例的地址
    mapping(address => address) public memeTokenToIssuer; // MemeToken地址 => 发行者地址
    mapping(address => address) public issuerToMemeToken; // 发行者地址 => MemeToken地址

    event MemeDeployed(address indexed memeAddress, address indexed issuer, string symbol, uint256 totalSupply, uint256 perMint, uint256 price);
    event MemeMinted(address indexed memeAddress, address indexed minter, address indexed to, uint256 amount, uint256 payment);

    constructor(address _memeTokenImplementation) Ownable(msg.sender) {
        require(_memeTokenImplementation != address(0), "MemeFactory: Invalid implementation address");
        MEME_TOKEN_IMPLEMENTATION = _memeTokenImplementation;
    }

    /**
     * @notice Meme 发行者调用该方法创建 ERC20 合约（MemeToken 实例）。
     * @param symbol 新创建代币的代号（ERC20 代币名字可以使用固定的）
     * @param totalSupply 总发行量
     * @param perMint 一次铸造 Meme 的数量
     * @param price 每个 Meme 铸造时需要的支付的费用 (wei 计价)
     * @return newMemeAddress 新部署的 MemeToken 合约地址
     */
    function deployMeme(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address newMemeAddress) {
        require(totalSupply > 0, "MemeFactory: Total supply must be greater than 0");
        require(perMint > 0, "MemeFactory: Per mint amount must be greater than 0");
        require(price > 0, "MemeFactory: Price must be greater than 0");
        require(issuerToMemeToken[msg.sender] == address(0), "MemeFactory: Issuer already deployed a meme");

        // 使用 Clones 库部署一个最小代理合约
        newMemeAddress = MEME_TOKEN_IMPLEMENTATION.cloneDeterministic(keccak256(abi.encodePacked(msg.sender, symbol, totalSupply, perMint, price, block.chainid)));
        // 为了演示，这里使用一个基于参数的确定性 salt。实际应用中可以使用更复杂的 salt。

        // 初始化新部署的 MemeToken 实例
        MemeToken(newMemeAddress).initialize(
            symbol,
            totalSupply,
            perMint,
            price,
            msg.sender, // MemeToken 的发行者是调用 deployMeme 的人
            owner()     // 项目方是 MemeFactory 的 owner
        );

        memeTokenToIssuer[newMemeAddress] = msg.sender;
        issuerToMemeToken[msg.sender] = newMemeAddress;

        emit MemeDeployed(newMemeAddress, msg.sender, symbol, totalSupply, perMint, price);
    }

    /**
     * @notice 购买 Meme 的用户每次调用该函数时，会发行 deployMeme 确定的 perMint 数量的 token，并收取相应的费用。
     * 这个函数是一个转发器，将调用委托给目标 MemeToken 合约。
     * @param tokenAddr 要铸造的 MemeToken 合约地址
     * @param to 接收铸造代币的地址
     */
    function mintMeme(address tokenAddr, address to) external payable {
        // 确保这个 tokenAddr 是通过本工厂部署的
        require(memeTokenToIssuer[tokenAddr] != address(0), "MemeFactory: Not a valid meme token deployed by this factory");

        // 获取 MemeToken 合约实例
        MemeToken meme = MemeToken(tokenAddr);

        // 计算所需的支付金额
        uint256 requiredPayment = meme.perMintAmount() * meme.mintPricePerUnit();
        require(msg.value >= requiredPayment, "MemeFactory: Insufficient payment for minting");

        // 直接调用 MemeToken 实例的 mintMeme 函数
        // 这里使用 call 而不是直接调用，以确保 msg.sender 和 msg.value 被正确传递
        (bool success, bytes memory returndata) = address(meme).call{value: msg.value}(
            abi.encodeWithSelector(meme.mintMeme.selector, to)
        );
        require(success, string(returndata)); // 如果调用失败，则revert并传递错误信息

        emit MemeMinted(tokenAddr, msg.sender, to, meme.perMintAmount(), requiredPayment);
    }

    // 获取某个 MemeToken 合约的总供应量（方便测试和查询）
    function getMemeTokenTotalSupply(address _tokenAddr) external view returns (uint256) {
        return ERC20(_tokenAddr).totalSupply();
    }
}