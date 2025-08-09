// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/console.sol";
/**
 * @title TransparentProxy
 * @dev 这是一个简单的透明代理合约。
 */
contract TransparentProxy {
    // 存储实现合约的地址
    address public implementation;

    // 存储管理员地址
    address public admin;

    // 仅管理员可用的修饰符
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    constructor(address _implementation, address _admin) {
        implementation = _implementation;
        admin = _admin;
    }

    /// @notice 升级到新的实现合约
    function upgrade(address newImplementation) external onlyAdmin {
        implementation = newImplementation;
    }

    /// @notice 接收以太币
    receive() external payable {}

    /// @notice 回退函数，将所有调用委托给实现合约
    fallback() external payable {
        // 使用 delegatecall 调用实现合约的函数
        console.log("Fallback called, delegating to implementation at:", implementation,"msg sender:", msg.sender);
        // console.log("Fallback called, msg data at:", msg.data);

        (bool success, bytes memory returndata) = implementation.delegatecall(msg.data);
        console.log("Fallback returned ", returndata);
        // 如果调用失败，回退并返回数据
        if (!success) {
            revert(string(returndata));
        }
    }
}
