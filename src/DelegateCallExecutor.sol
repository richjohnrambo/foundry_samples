// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


/**
 * @title DelegateCallExecutor
 * @dev A contract that allows a signer to authorize and delegate a batch of calls.
 * This is a simplified implementation based on EIP-7702 concepts.
 */
contract DelegateCallExecutor {

     /// @notice 封装单个调用所需的参数
    struct Call {
        address to;
        bytes data;
        uint256 value;
    }

    /// @notice 当一个调用被成功执行时触发的事件
    /// @param to 调用的目标地址
    /// @param value 调用附带的以太币数量
    /// @param data 调用的 calldata
    event Executed(address to, uint256 value, bytes data);

    /// @notice 批量执行一系列调用
    /// @param calls 包含所有待执行调用的数组
    /// @dev 该函数是 payable 的，允许交易附带以太币。
    /// @dev 它依赖于 EOA 的 EIP-7702 授权来执行内部的 calls。
    function execute(Call[] memory calls) external payable {
        for (uint256 i = 0; i < calls.length; i++) {
            Call memory call = calls[i];
            
            // 使用低级 `call` 指令执行内部调用
            // 批量调用的成功或失败依赖于此处的 success 变量
            (bool success, bytes memory result) = call.to.call{value: call.value}(call.data);
            
            // 如果任何一个内部调用失败，则整个批量调用回滚，并返回内部调用的错误信息
            require(success, string(result));

            // 发出事件，用于链上追踪
            emit Executed(call.to, call.value, call.data);
        }
    }
}


