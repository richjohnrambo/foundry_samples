// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/console.sol";
/**
 * @title TransparentProxy
 * @dev 这是一个透明代理合约，它使用 ERC1967 标准来存储实现合约地址和管理员地址。
 * 它确保在进行 delegatecall 时，只将调用转发给实现合约，而不会发生存储冲突。
 */
contract TransparentProxy {

    // 使用 ERC1967 标准的存储槽，防止与实现合约的变量发生冲突
    // 存储槽地址为 keccak256("erc1967.proxy.implementation") - 1
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // 存储槽地址为 keccak256("erc1967.proxy.admin") - 1
    bytes32 private constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a7178553251581;

    // 事件
    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev 构造函数初始化代理，设置实现合约和管理员地址。
     * @param _implementation 实现合约的地址。
     * @param _admin 管理员的地址。
     */
    constructor(address _implementation, address _admin) {
        require(_implementation != address(0), "Implementation cannot be zero address");
        _setImplementation(_implementation);
        _setAdmin(_admin);
    }

    /**
     * @dev Fallback 函数，用于将调用转发到实现合约。
     * 它检查调用者是否为管理员，如果是，则允许其调用代理自身的方法。
     * 如果不是，则通过 delegatecall 将调用转发给实现合约。
     */
    fallback() external payable {
        address target = _implementation();
        console.log("Fallback called, target implementation:", target);

        if (msg.sender != _admin() || (msg.data.length > 0 
            && bytes4(msg.data) != this.upgrade.selector && bytes4(msg.data) != this.admin.selector 
            && bytes4(msg.data) != this.implementation.selector)) {
            
            (bool success, bytes memory returndata) = target.delegatecall(msg.data);
            if (!success) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            assembly {
                returndatacopy(0, 0, returndatasize())
                return(0, returndatasize())
            }
        }
    }


     receive() external payable {}

    /**
     * @notice 升级到新的实现合约。
     * @param newImplementation 新的实现合约地址。
     */
    function upgrade(address newImplementation) external {
        require(msg.sender == _admin(), "Only admin can call this function");
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }
    
    /**
     * @notice 获取当前的实现合约地址。
     */
    function implementation() public view returns (address) {
        return _implementation();
    }
    
    /**
     * @notice 获取当前的管理员地址。
     */
    function admin() public view returns (address) {
        return _admin();
    }
    
    /**
     * @dev 返回代理的管理员地址。
     */
    function _admin() internal view returns (address adm) {
        bytes32 slot = _ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }

    /**
     * @dev 返回代理的实现合约地址。
     */
    function _implementation() internal view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    /**
     * @dev 设置新的实现合约地址。
     * @param newImplementation 新的实现合约地址。
     */
    function _setImplementation(address newImplementation) internal {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }

    /**
     * @dev 设置新的管理员地址。
     * @param newAdmin 新的管理员地址。
     */
    function _setAdmin(address newAdmin) internal {
        bytes32 slot = _ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }
}
