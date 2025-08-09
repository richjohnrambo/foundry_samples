// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./CloudToken.sol";

/**
 * @title NFTMarketV1
 * @dev 这是一个 V1 版本的 NFT 市场合约。
 */
contract NFTMarketV1 is Ownable {
    // 存储上架 NFT 的信息
    struct Listing {
        uint256 price;   // NFT 价格
        address seller;  // 卖方地址
    }

    IERC721 public nftContract;
    CloudToken public paymentToken;
    mapping(uint256 => Listing) public listings;
    
    // 用于防止重复初始化的标志
    bool private _initialized;

    event List(address indexed from, uint256 tokenId, uint256 price);
    event Buy(address indexed seller, address indexed buyer, uint256 tokenId, uint256 price);

    // 构造函数为空，以便通过代理模式部署
    constructor() {}

    /**
     * @notice 初始化合约，在通过代理部署时调用。
     * @param _nft 要交易的 NFT 合约地址。
     * @param _paymentToken 用于支付的代币合约地址。
     * @param _initialOwner 初始所有者的地址。
     */
    function initialize(address _nft, address _paymentToken, address _initialOwner) external {
        require(!_initialized, "Already initialized");
        _initialized = true;
        _transferOwnership(_initialOwner); // 在此设置所有者
        
        nftContract = IERC721(_nft);
        paymentToken = CloudToken(_paymentToken);
    }
    
    /**
     * @notice 上架 NFT。
     * @param tokenId 要上架的 NFT 的 ID。
     * @param price 设定的 NFT 价格。
     */
    function list(uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than zero");
        
        address nftOwner = nftContract.ownerOf(tokenId);
        require(nftOwner == msg.sender, "You are not the owner of the NFT");
        
        // 将 NFT 转移到市场合约
        nftContract.transferFrom(nftOwner, address(this), tokenId);
        
        listings[tokenId] = Listing({
            price: price,
            seller: msg.sender
        });

        emit List(msg.sender, tokenId, price);

    }
    
    /**
     * @notice 购买已上架的 NFT。
     * @param tokenId 要购买的 NFT 的 ID。
     */
    function buyNFT(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];
        uint256 price = listing.price;
        address seller = listing.seller;

        require(price > 0, "This NFT is not for sale");
        require(msg.sender != seller, "Cannot buy your own NFT");
        
        // 从买方转移支付代币到卖方
        require(paymentToken.transferFrom(msg.sender, seller, price), "Payment failed");
        
        // 将 NFT 转移给买方
        nftContract.transferFrom(address(this), msg.sender, tokenId);

        // 删除上架信息
        delete listings[tokenId];
        emit Buy(seller, msg.sender, tokenId, price);
    }
}
