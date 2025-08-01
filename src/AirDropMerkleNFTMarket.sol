// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

import "./RedToken.sol";
import "./MyNFT.sol";

/**
 * @title AirdropMerkleNFTMarket
 * @dev 基于 Merkle 树的 NFT 市场，支持白名单用户 50% 折扣购买
 * 
 */
contract AirdropMerkleNFTMarket is ReentrancyGuard, Ownable, Multicall {
    
    // ================================ 状态变量 ================================
    
    RedToken public immutable paymentToken;
    MyNFT public immutable nftContract;
    bytes32 public merkleRoot;
    
    struct NFTListing {
        address seller;
        uint256 price;
        bool isActive;
    }
    
    // NFT ID => Listing 信息
    mapping(uint256 => NFTListing) public nftListings;
    
    // 用户地址 => 是否已领取
    mapping(address => bool) public hasClaimed;
    
    // ================================ 事件 ================================
    
    event NFTListed(uint256 indexed nftId, address indexed seller, uint256 price);
    event NFTClaimed(
        address indexed buyer, 
        uint256 indexed nftId, 
        uint256 originalPrice, 
        uint256 discountedPrice
    );
    event MerkleRootUpdated(bytes32 oldRoot, bytes32 newRoot);
    
    // ================================ 错误 ================================
    
    error AlreadyClaimed();
    error NotInWhitelist();
    error NFTNotListed();
    error NFTNotActive();
    error InsufficientPayment();
    error InvalidProof();
    error TransferFailed();
    
    // ================================ 构造函数 ================================
    
    constructor(
        address _paymentToken,
        address _nftContract,
        bytes32 _merkleRoot,
        address _owner  // 额外参数：指定所有者
    ) Ownable(_owner) {
        paymentToken = RedToken(_paymentToken);
        nftContract = MyNFT(_nftContract);
        merkleRoot = _merkleRoot;
    }
    
    // ================================ 核心功能 ================================
    
    /**
     * @dev 上架 NFT
     */
    function listNFT(uint256 nftId, uint256 price) external {
        require(nftContract.ownerOf(nftId) == msg.sender, "Not NFT owner");
        require(price > 0, "Price must be greater than 0");
        
        nftListings[nftId] = NFTListing({
            seller: msg.sender,
            price: price,
            isActive: true
        });
        
        emit NFTListed(nftId, msg.sender, price);
    }
    
    /**
     * @dev 1. permitPrePay - 处理 permit 授权
     */
    function permitPrePay(
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        paymentToken.permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
    }
    
    /**
     * @dev 2. claimNFT - 验证白名单并购买 NFT
     */
    function claimNFT(
        bytes32[] calldata merkleProof,
        uint256 nftId
    ) external nonReentrant {
        // 检查是否已领取
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        
        // 验证 Merkle 证明
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
            revert NotInWhitelist();
        }
        
        // 获取 NFT 信息
        NFTListing storage listing = nftListings[nftId];
        if (listing.seller == address(0)) revert NFTNotListed();
        if (!listing.isActive) revert NFTNotActive();
        
        // 计算折扣价格 (50% off)
        uint256 discountedPrice = listing.price / 2;
        
        // 检查用户余额
        require(paymentToken.balanceOf(msg.sender) >= discountedPrice, "Insufficient balance");
        
        // 标记已领取
        hasClaimed[msg.sender] = true;
        listing.isActive = false;
        
        // 转账 Token
        bool success = paymentToken.transferFrom(msg.sender, listing.seller, discountedPrice);
        if (!success) revert TransferFailed();
        
        // 转移 NFT
        nftContract.transferFrom(listing.seller, msg.sender, nftId);
        
        emit NFTClaimed(msg.sender, nftId, listing.price, discountedPrice);
    }
    
    // ================================ 管理员功能 ================================
    
    /**
     * @dev 更新 Merkle 根
     */
    function updateMerkleRoot(bytes32 _newMerkleRoot) external onlyOwner {
        bytes32 oldRoot = merkleRoot;
        merkleRoot = _newMerkleRoot;
        emit MerkleRootUpdated(oldRoot, _newMerkleRoot);
    }
    
    // ================================ 查询函数 ================================
    
    /**
     * @dev 获取 NFT 上架信息
     */
    function getNFTListing(uint256 nftId) external view returns (NFTListing memory) {
        return nftListings[nftId];
    }
    
    /**
     * @dev 验证用户是否在白名单中
     */
    function verifyWhitelist(
        address user,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }
}