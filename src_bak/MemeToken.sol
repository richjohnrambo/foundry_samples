// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// MemeToken 将是工厂合约通过最小代理创建的模板合约
contract MemeToken is ERC20, Ownable, UUPSUpgradeable {
    using Address for address payable;

    string public constant NAME = "My Awesome Meme"; // 固定代币名字
    uint256 public totalSupplyLimit; // 总发行量上限
    uint256 public perMintAmount;    // 每次铸造数量
    uint256 public mintPricePerUnit; // 每个 Meme 铸造时需要支付的费用 (wei计价)

    address public memeIssuer; // Meme 的发行者 (即部署这个 MemeToken 的用户)
    address public projectOwner; // 项目方地址 (工厂合约的 owner)

    // 避免在构造函数中初始化，因为这是通过代理部署的
    function initialize(
        string memory symbol_,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _mintPricePerUnit,
        address _memeIssuer,
        address _projectOwner
    ) public initializer {
        __ERC20_init(NAME, symbol_);
        __Ownable_init(_memeIssuer); // MemeToken 的所有者是其发行者
        __UUPSUpgradeable_init();

        totalSupplyLimit = _totalSupply;
        perMintAmount = _perMint;
        mintPricePerUnit = _mintPricePerUnit;
        memeIssuer = _memeIssuer;
        projectOwner = _projectOwner;
    }

    // 只有项目方（Project Owner）可以升级合约
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        // UUPSUpgradeable 中的 onlyOwner 是指 MemeToken 的 owner，也就是 memeIssuer
        // 所以这里需要额外检查调用者是否是项目方 (projectOwner)
        require(msg.sender == projectOwner, "MemeToken: Only project owner can upgrade");
    }

    /**
     * @notice 购买 Meme 的用户调用此函数。
     * 会铸造 `perMintAmount` 数量的代币，并收取相应的费用。
     * @param to 接收铸造代币的地址
     */
    function mintMeme(address to) public payable {
        // 确保传入了足够的 ETH
        uint256 requiredPayment = perMintAmount * mintPricePerUnit;
        require(msg.value >= requiredPayment, "MemeToken: Insufficient payment");

        // 检查是否超过总供应量限制
        uint256 currentSupply = totalSupply();
        uint256 amountToMint = perMintAmount;
        require(currentSupply + amountToMint <= totalSupplyLimit, "MemeToken: Exceeds total supply limit");

        // 计算费用分配
        // 项目方分得 1%
        uint256 projectFee = (requiredPayment * 1) / 100;
        // Meme 发行者分得 99%
        uint256 memeIssuerShare = requiredPayment - projectFee;

        // 转移 ETH 给项目方
        payable(projectOwner).sendValue(projectFee);

        // 转移 ETH 给 Meme 发行者
        payable(memeIssuer).sendValue(memeIssuerShare);

        // 铸造代币
        _mint(to, amountToMint);

        // 退还多余的 ETH (如果有的话)
        if (msg.value > requiredPayment) {
            payable(msg.sender).sendValue(msg.value - requiredPayment);
        }
    }

    // 覆盖 _msgSender() 以在代理环境中正确获取调用者
    function _msgSender() internal view virtual override(Context, Ownable) returns (address) {
        return Context._msgSender();
    }
    
    // 覆盖 _msgData() 以在代理环境中正确获取消息数据
    function _msgData() internal view virtual override(Context, Ownable) returns (bytes calldata) {
        return Context._msgData();
    }

    // 额外添加一个 allowlistMint 函数，假设只有白名单用户可以铸造
    // 假设这个 MemeToken 的 owner 可以管理白名单，
    // 即 memeIssuer 可以管理白名单
    mapping(address => bool) public mintWhitelist;

    function addToMintWhitelist(address user) public onlyOwner {
        mintWhitelist[user] = true;
    }

    function removeFromMintWhitelist(address user) public onlyOwner {
        mintWhitelist[user] = false;
    }

    // 白名单铸造，只有在白名单内的用户才能调用
    function allowlistMint(address to) public payable {
        require(mintWhitelist[msg.sender], "MemeToken: Not whitelisted for minting");
        mintMeme(to); // 调用核心铸造逻辑
    }
}