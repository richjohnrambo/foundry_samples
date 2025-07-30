// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MyERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/permit2/contracts/interfaces/IPermit2.sol"; // 导入 Permit2 接口

contract TokenBank  {
    mapping(address => mapping(address => uint256)) public balances; // user => token => amount
    address public immutable PERMIT2_ADDRESS; // Permit2 合约地址

    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    
    constructor(address _permit2Address) {
        PERMIT2_ADDRESS = _permit2Address;
    }

    /**
     * @notice 存款方法：传统方式，用户需要先 approve TokenBank
     * @param tokenAddr 存款代币地址
     * @param amount 存款数量
     */
    function deposit(address tokenAddr, uint256 amount) public {
        require(amount > 0, "Deposit: amount must be greater than 0");
        
        // 从用户转账代币到 TokenBank
        MyERC20(tokenAddr).transferFrom(msg.sender, address(this), amount);
        balances[msg.sender][tokenAddr] += amount;

        emit Deposited(msg.sender, tokenAddr, amount);
    }

    /**
     * @notice 提款方法
     * @param tokenAddr 提款代币地址
     * @param amount 提款数量
     */
    function withdraw(address tokenAddr, uint256 amount) public {
        require(amount > 0, "Withdraw: amount must be greater than 0");
        require(balances[msg.sender][tokenAddr] >= amount, "Withdraw: insufficient balance");

        balances[msg.sender][tokenAddr] -= amount;
        IERC20(tokenAddr).transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, tokenAddr, amount);
    }

    /**
     * @notice 使用 Permit2 签名授权转账进行存款
     * @param tokenAddr 存款代币地址
     * @param amount 存款数量
     * @param permit2Signature Permit2 签名数据
     * @param permit Permit2 结构体数据
     */
    function depositWithPermit2(
        address tokenAddr,
        uint256 amount,
        bytes memory permit2Signature,
        IPermit2.PermitSingle memory permit // 使用 Permit2 接口中的 PermitSingle 结构体
    ) public {
        require(amount > 0, "DepositWithPermit2: amount must be greater than 0");

        // 验证 Permit2 签名并执行代币转账
        // 调用 Permit2 合约的 'permit' 方法来验证签名并执行授权的 transferFrom
        // 注意：permit2.permit() 会消耗掉签名，防止重放攻击
        IPermit2(PERMIT2_ADDRESS).permit(
            msg.sender, // signer 应该是调用 depositWithPermit2 的用户
            permit,
            permit2Signature
        );

        // Permit2 成功后，代币已经从用户那里转移到了 TokenBank 的地址
        // 所以我们不需要再调用 transferFrom 了，只需要更新 TokenBank 内部的余额
        balances[msg.sender][tokenAddr] += amount;

        emit Deposited(msg.sender, tokenAddr, amount);
    }

    // 可以添加其他 onlyOwner 的管理功能
}