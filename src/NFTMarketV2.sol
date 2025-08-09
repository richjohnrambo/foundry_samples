// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./CloudToken.sol";
import "forge-std/console.sol";

/**
 * @title NFTMarketV2
 * @dev V2 版本，新增离线签名上架；已调整 storage 布局以兼容 V1，
 * 并使 buyNFT 能同时处理“NFT 在合约托管（V1）”和“NFT 在卖方手中（V2）”两种情况。
 */
contract NFTMarketV2 is Ownable {
    using ECDSA for bytes32;

    // 与 V1 一致的 storage 布局（顺序不能改）
    struct Listing {
        uint256 price;
        address seller;
    }

    IERC721 public nftContract;
    CloudToken public paymentToken;
    mapping(uint256 => Listing) public listings;

    // 保持与 V1 相同的位置
    bool private _initialized;

    // 新增变量必须追加（放在这里，确保不改变 listings 的 slot）
    mapping(bytes32 => bool) public usedSignatures;

    event ListWithSignature(address indexed from, uint256 tokenId, uint256 price);
    event Buy(address indexed seller, address indexed buyer, uint256 tokenId, uint256 price);

    constructor() Ownable(msg.sender) {}

    function initialize(address _nft, address _paymentToken, address _initialOwner) external {
        require(!_initialized, "Already initialized");
        _initialized = true;
        _transferOwnership(_initialOwner);

        nftContract = IERC721(_nft);
        paymentToken = CloudToken(_paymentToken);
    }

    /**
     * @notice 通过离线签名上架 NFT。
     * 说明：上架时会把 NFT 转到合约（代理）用于托管（与 V1 保持一致的托管模型）。
     */
    function listWithSignature(uint256 tokenId, uint256 price, bytes calldata signature) external {
        require(price > 0, "Price must be greater than zero");

        bytes32 messageHash = _getMessageHash(tokenId, price);
        bytes32 signatureHash = keccak256(abi.encodePacked(signature));
        require(!usedSignatures[signatureHash], "Signature already used");

        // NOTE: 使用你原来的恢复逻辑（未使用 toEthSignedMessageHash）
        address seller = messageHash.recover(signature);
        require(seller != address(0), "Invalid signature");

        console.log("NFT owner before listing:", nftContract.ownerOf(tokenId), "Expected seller:", seller);
        require(nftContract.ownerOf(tokenId) == seller, "You are not the owner of the NFT");

        usedSignatures[signatureHash] = true;

        // 将 NFT 转到合约（代理）进行托管（与 V1 的 list 行为一致）
        nftContract.transferFrom(seller, address(this), tokenId);

        listings[tokenId] = Listing({
            price: price,
            seller: seller
        });

        emit ListWithSignature(seller, tokenId, price);
    }

    /**
     * @notice 购买已上架的 NFT（兼容 V1 托管与 V2 直持两种情形）。
     */
    function buyNFT(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];
        uint256 price = listing.price;
        address seller = listing.seller;

        require(price > 0, "This NFT is not for sale");
        require(msg.sender != seller, "Cannot buy your own NFT");

        // 从买方转移支付代币到卖方
        require(paymentToken.transferFrom(msg.sender, seller, price), "Payment failed");

        // 兼容逻辑：检查当前 owner 决定从哪里转 NFT
        address currentOwner = nftContract.ownerOf(tokenId);

        if (currentOwner == address(this)) {
            // NFT 在合约托管（V1 上架），从合约转给买家
            nftContract.transferFrom(address(this), msg.sender, tokenId);
        } else {
            // NFT 在卖方手中（V2 风格），从卖方转给买家
            nftContract.transferFrom(seller, msg.sender, tokenId);
        }

        // 删除上架信息
        delete listings[tokenId];
        emit Buy(seller, msg.sender, tokenId, price);
    }

    function _getMessageHash(uint256 tokenId, uint256 price) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(tokenId, price));
    }
}
