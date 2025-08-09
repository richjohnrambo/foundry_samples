// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Foundry 导入路径
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title CloudNFT
 * @dev 这是一个可升级的 NFT 合约，为市场而设计。
 * 它继承了 OpenZeppelin 的 ERC721 标准，不使用 UUPS 模式进行升级。
 */
/**
 * @title CloudNFT
 * @dev 这是一个可升级的 NFT 合约，为市场而设计。
 * 它继承了 OpenZeppelin 的 ERC721 标准，不使用 UUPS 模式进行升级。
 */
contract CloudNFT is Initializable, ERC721URIStorageUpgradeable, OwnableUpgradeable {
    uint256 private _tokenIdCounter;

    /**
     * @notice 合约的初始化函数，替代构造函数。
     * @dev 只能被调用一次。
     */
    function initialize() public initializer {
        // 初始化所有继承的合约
        // ERC721 的初始化需要 name 和 symbol
        __ERC721_init("CloudNFT", "CFT");
        // ERC721URIStorage 和 Ownable 的初始化不需要参数
        __ERC721URIStorage_init();
        __Ownable_init(msg.sender);
        _tokenIdCounter = 0;
    }

    /**
     * @notice 铸造一个新的 NFT。
     * @dev 只能由合约所有者调用。
     * @param to 接收 NFT 的地址。
     * @param uri NFT 的元数据 URI。
     */
    function mint(address to, string memory uri) public onlyOwner returns (uint256) {
        uint256 newTokenId = _tokenIdCounter;
        
        // 使用 ERC721 的标准函数来铸造和设置 URI
        _mint(to, newTokenId);
        _setTokenURI(newTokenId, uri);
        
        _tokenIdCounter++;
        return newTokenId;
    }

    /**
     * @notice 获取下一个可用的 token ID。
     */
    function currentTokenId() public view returns (uint256) {
        return _tokenIdCounter;
    }
}
