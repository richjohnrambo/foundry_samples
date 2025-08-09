// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
// 修复：将 ECDSAUpgradeable 替换为正确的 ECDSA
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// 使用标准的 IERC721 和 IERC20
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/**
 * @title NFTMarket_V2
 * @dev 这是可升级 NFT 市场的第二个版本。
 * 它引入了 EIP-712 支持，用于实现无需转移 NFT 的链下签名上架。
 */
contract NFTMarket_V2 is Initializable, OwnableUpgradeable, EIP712Upgradeable {
    // 移除 using for 语法以修复编译器错误，直接调用 ECDSA 库的函数。

    struct Listing {
        uint256 price;
        address seller; // 卖家的地址
        bool isSignedListing; // true 表示这是 V2 签名上架，false 表示 V1 传统上架
    }

    IERC721 public nftContract;
    IERC20 public paymentToken;

    mapping(uint256 => Listing) public listings;
    // 用于防止签名重放攻击的 Nonce
    mapping(address => uint256) public nonces;

    event Listed(address indexed from, uint256 tokenId, uint256 price, bool isSignedListing);
    event Bought(address indexed seller, address indexed buyer, uint256 tokenId, uint256 price);

    // EIP-712 签名的数据结构
    bytes32 private constant LISTING_TYPEHASH = keccak256("Listing(uint256 tokenId,uint256 price,uint256 nonce)");

    /**
     * @notice 初始化合约。
     * @dev 这个函数代替了构造函数，用于可升级合约。
     * @param _nftContract NFT 合约的地址。
     * @param _paymentToken 支付代币合约的地址。
     */
    function initialize(address _nftContract, address _paymentToken) public initializer {
        __Ownable_init(msg.sender);
        __EIP712_init("NFTMarket_V2", "1.0");
        
        nftContract = IERC721(_nftContract);
        paymentToken = IERC20(_paymentToken);
    }

    /**
     * @notice 传统的上架方式，将 NFT 转移到市场合约中。
     * @param tokenId 要上架的 NFT 的 ID。
     * @param price NFT 的价格。
     */
    function list(uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than zero");
        require(nftContract.ownerOf(tokenId) == msg.sender, "You must own the NFT");
        
        // 传统的上架方式，NFT 转移到市场合约中
        nftContract.transferFrom(msg.sender, address(this), tokenId);

        listings[tokenId] = Listing({
            price: price,
            seller: msg.sender,
            isSignedListing: false
        });
        
        emit Listed(msg.sender, tokenId, price, false);
    }

    /**
     * @notice 离线签名上架 NFT，NFT 保留在卖家手中。
     * @param tokenId 要上架的 NFT 的 ID。
     * @param price NFT 的价格。
     * @param signature 卖家对上架信息的 EIP-712 签名。
     */
    function listWithSignature(uint256 tokenId, uint256 price, bytes memory signature) external {
        require(price > 0, "Price must be greater than zero");
        
        // 1. 获取签名中的 Nonce，并检查其有效性
        uint256 nonce = nonces[msg.sender];
        nonces[msg.sender] = nonce + 1;

        // 2. 构造 EIP-712 哈希
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            LISTING_TYPEHASH,
            tokenId,
            price,
            nonce
        )));

        // 3. 直接调用 ECDSA 库的 recover 函数来恢复签名者的地址
        address signer = ECDSA.recover(digest, signature);
        
        // 4. 验证签名者是 NFT 的所有者
        require(signer == nftContract.ownerOf(tokenId), "Invalid signature or not NFT owner");
        
        // 5. 存储上架信息
        listings[tokenId] = Listing({
            price: price,
            seller: signer,
            isSignedListing: true
        });

        emit Listed(signer, tokenId, price, true);
    }


    /**
     * @notice 购买一个已经上架的 NFT。
     * @dev 该函数现在支持两种上架方式：V1（NFT 在市场合约中）和 V2（NFT 在卖家手中）。
     * @param tokenId 要购买的 NFT 的 ID。
     */
    function buyNFT(uint256 tokenId) public {
        Listing memory listing = listings[tokenId];
        
        uint256 price = listing.price;
        address seller = listing.seller;

        require(price > 0, "This NFT is not for sale");
        require(msg.sender != seller, "Cannot buy your own NFT");
        
        // 转移代币：从买家 -> 卖家
        require(paymentToken.transferFrom(msg.sender, seller, price), "Payment failed");

        if (listing.isSignedListing) {
            // V2 签名上架：NFT 仍在卖家手中
            // 需要卖家已提前对市场合约 setApprovalForAll
            require(nftContract.isApprovedForAll(seller, address(this)), "Seller must approve market contract");
            // 直接从卖家地址转移 NFT 到买家地址
            nftContract.transferFrom(seller, msg.sender, tokenId);
        } else {
            // V1 传统上架：NFT 在市场合约中
            require(nftContract.ownerOf(tokenId) == address(this), "NFT must be held by the market for V1 listings");
            // 从市场合约转移 NFT 到买家地址
            nftContract.transferFrom(address(this), msg.sender, tokenId);
        }

        // 交易完成后，删除上架记录
        delete listings[tokenId];
        emit Bought(seller, msg.sender, tokenId, price);
    }
}
