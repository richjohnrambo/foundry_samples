// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/Permit2Vault.sol";
import "./TestUtils.sol";

contract Permit2VaultTest is TestUtils {
    bytes32 constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );
    bytes32 constant PERMIT_BATCH_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    Permit2Clone permit2 = new Permit2Clone();
    TestERC20 token1 = new TestERC20();
    TestERC20 token2 = new TestERC20();
    ReenteringERC20 badToken = new ReenteringERC20();
    Permit2Vault vault;
    uint256 ownerKey;
    address owner;

    constructor() {
        vm.chainId(1);
        vault = new Permit2Vault(permit2);
        ownerKey = _randomUint256();
        owner = vm.addr(ownerKey);
        // Set up unlimited token approvals from the user onto the permit2 contract.
        vm.prank(owner);
        token1.approve(address(permit2), type(uint256).max);
        vm.prank(owner);
        token2.approve(address(permit2), type(uint256).max);
    }

    function test_canDeposit() external {
        uint256 amount = _randomUint256() % 1e18 + 1;
        token1.mint(owner, amount);
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: IERC20(address(token1)),
                amount: amount
            }),
            nonce: _randomUint256(),
            deadline: block.timestamp
        });
        bytes memory sig = _signPermit(permit, address(vault), ownerKey);
        vm.prank(owner);
        vault.depositERC20(
            IERC20(address(token1)),
            amount,
            permit.nonce,
            permit.deadline,
            sig
        );
        assertEq(vault.tokenBalancesByUser(owner, IERC20(address(token1))), amount);
        assertEq(token1.balanceOf(address(vault)), amount);
        assertEq(token1.balanceOf(owner), 0);
    }

    function test_cannotReusePermit() external {
        uint256 amount = _randomUint256() % 1e18 + 1;
        token1.mint(owner, amount);
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: IERC20(address(token1)),
                amount: amount
            }),
            nonce: _randomUint256(),
            deadline: block.timestamp
        });
        bytes memory sig = _signPermit(permit, address(vault), ownerKey);
        vm.prank(owner);
        vault.depositERC20(
            IERC20(address(token1)),
            amount,
            permit.nonce,
            permit.deadline,
            sig
        );
        vm.expectRevert(abi.encodeWithSelector(Permit2Clone.InvalidNonce.selector));
        vm.prank(owner);
        vault.depositERC20(
            IERC20(address(token1)),
            amount,
            permit.nonce,
            permit.deadline,
            sig
        );
    }

    function test_cannotUseOthersPermit() external {
        uint256 amount = _randomUint256() % 1e18 + 1;
        token1.mint(owner, amount);
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: IERC20(address(token1)),
                amount: amount
            }),
            nonce: _randomUint256(),
            deadline: block.timestamp
        });
        bytes memory sig = _signPermit(permit, address(vault), ownerKey);
        vm.expectRevert(abi.encodeWithSelector(Permit2Clone.InvalidSigner.selector));
        vm.prank(_randomAddress());
        vault.depositERC20(
            IERC20(address(token1)),
            amount,
            permit.nonce,
            permit.deadline,
            sig
        );
    }

    function test_cannotUseOtherTokenPermit() external {
        vm.prank(owner);
        token2.approve(address(permit2), type(uint256).max);
        uint256 amount = _randomUint256() % 1e18 + 1;
        token1.mint(owner, amount);
        token2.mint(owner, amount);
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: IERC20(address(token2)),
                amount: amount
            }),
            nonce: _randomUint256(),
            deadline: block.timestamp
        });
        bytes memory sig = _signPermit(permit, address(vault), ownerKey);
        vm.prank(owner);
        vm.expectRevert(Permit2Clone.InvalidSigner.selector);
        vault.depositERC20(
            IERC20(address(token1)),
            amount,
            permit.nonce,
            permit.deadline,
            sig
        );
    }

    function test_canWithdraw() external {
        uint256 amount = _randomUint256() % 1e18 + 2;
        token1.mint(owner, amount);
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: IERC20(address(token1)),
                amount: amount
            }),
            nonce: _randomUint256(),
            deadline: block.timestamp
        });
        bytes memory sig = _signPermit(permit, address(vault), ownerKey);
        vm.prank(owner);
        vault.depositERC20(
            IERC20(address(token1)),
            amount,
            permit.nonce,
            permit.deadline,
            sig
        );
        vm.prank(owner);
        vault.withdrawERC20(IERC20(address(token1)), amount - 1);
        assertEq(token1.balanceOf(owner), amount - 1);
        assertEq(token1.balanceOf(address(vault)), 1);
    }

    function test_cannotWithdrawOthers() external {
        uint256 amount = _randomUint256() % 1e18 + 1;
        token1.mint(owner, amount);
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: IERC20(address(token1)),
                amount: amount
            }),
            nonce: _randomUint256(),
            deadline: block.timestamp
        });
        bytes memory sig = _signPermit(permit, address(vault), ownerKey);
        vm.prank(owner);
        vault.depositERC20(
            IERC20(address(token1)),
            amount,
            permit.nonce,
            permit.deadline,
            sig
        );
        vm.expectRevert();
        vm.prank(_randomAddress());
        vault.withdrawERC20(IERC20(address(token1)), amount);
    }

    function test_cannotReenter() external {
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: IERC20(address(badToken)),
                amount: 0
            }),
            nonce: _randomUint256(),
            deadline: block.timestamp
        });
        bytes memory sig = _signPermit(permit, address(vault), ownerKey);
        // Reenter by calling withdrawERC20() in transferFrom()
        badToken.setReentrantCall(
            address(vault),
            abi.encodeCall(vault.withdrawERC20, (IERC20(address(badToken)), 0))
        );
        // Will manifest as a TRANSFER_FROM_FAILED
        vm.expectRevert('TRANSFER_FROM_FAILED');
        vm.prank(owner);
        vault.depositERC20(
            IERC20(address(badToken)),
            0,
            permit.nonce,
            permit.deadline,
            sig
        );
    }

    function test_canBatchDeposit() external {
        uint256 amount1 = _randomUint256() % 1e18 + 1;
        uint256 amount2 = _randomUint256() % 1e18 + 1;
        token1.mint(owner, amount1);
        token2.mint(owner, amount2);
        IPermit2.TokenPermissions[] memory permitted = new IPermit2.TokenPermissions[](2);
        permitted[0] = IPermit2.TokenPermissions({
            token: IERC20(address(token1)),
            amount: amount1
        });
        permitted[1] = IPermit2.TokenPermissions({
            token: IERC20(address(token2)),
            amount: amount2
        });
        IPermit2.PermitBatchTransferFrom memory permit = IPermit2.PermitBatchTransferFrom({
            permitted: permitted,
            nonce: _randomUint256(),
            deadline: block.timestamp
        });
        bytes memory sig = _signPermit(permit, address(vault), ownerKey);
        vm.prank(owner);
        {
            IERC20[] memory tokens = new IERC20[](permitted.length);
            uint256[] memory amounts = new uint256[](permitted.length);
            for (uint256 i; i < permitted.length; ++i) {
                (tokens[i], amounts[i]) = (permitted[i].token, permitted[i].amount);
            }
            vault.depositBatchERC20(
                tokens,
                amounts,
                permit.nonce,
                permit.deadline,
                sig
            );
        }
        assertEq(vault.tokenBalancesByUser(owner, IERC20(address(token1))), amount1);
        assertEq(vault.tokenBalancesByUser(owner, IERC20(address(token2))), amount2);
        assertEq(token1.balanceOf(address(vault)), amount1);
        assertEq(token2.balanceOf(address(vault)), amount2);
        assertEq(token1.balanceOf(owner), 0);
        assertEq(token2.balanceOf(owner), 0);
    }

    // Generate a signature for a permit message.
    function _signPermit(
        IPermit2.PermitTransferFrom memory permit,
        address spender,
        uint256 signerKey
    )
        internal
        view
        returns (bytes memory sig)
    {
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(signerKey, _getEIP712Hash(permit, spender));
        return abi.encodePacked(r, s, v);
    }

    // Generate a signature for a batch permit message.
    function _signPermit(
        IPermit2.PermitBatchTransferFrom memory permit,
        address spender,
        uint256 signerKey
    )
        internal
        view
        returns (bytes memory sig)
    {
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(signerKey, _getEIP712Hash(permit, spender));
        return abi.encodePacked(r, s, v);
    }

    // Compute the EIP712 hash of the permit object.
    // Normally this would be implemented off-chain.
    function _getEIP712Hash(IPermit2.PermitTransferFrom memory permit, address spender)
        internal
        view
        returns (bytes32 h)
    {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            permit2.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(
                PERMIT_TRANSFER_FROM_TYPEHASH,
                keccak256(abi.encode(
                    TOKEN_PERMISSIONS_TYPEHASH,
                    permit.permitted.token,
                    permit.permitted.amount
                )),
                spender,
                permit.nonce,
                permit.deadline
            ))
        ));
    }

    // Compute the EIP712 hash of the batch permit object.
    // Normally this would be implemented off-chain.
    function _getEIP712Hash(IPermit2.PermitBatchTransferFrom memory permit, address spender)
        internal
        view
        returns (bytes32 h)
    {
        bytes32 permittedHash;
        {
            uint256 n = permit.permitted.length;
            bytes32[] memory contentHashes = new bytes32[](n);
            for (uint256 i; i < n; ++i) {
                contentHashes[i] = keccak256(abi.encode(
                    TOKEN_PERMISSIONS_TYPEHASH,
                    permit.permitted[i].token,
                    permit.permitted[i].amount
                ));
            }
            permittedHash = keccak256(abi.encodePacked(contentHashes));
        }
        return keccak256(abi.encodePacked(
            "\x19\x01",
            permit2.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(
                PERMIT_BATCH_TRANSFER_FROM_TYPEHASH,
                permittedHash,
                spender,
                permit.nonce,
                permit.deadline
            ))
        ));
    }
}

contract TestERC20 is ERC20 {
    constructor() ERC20("Test", "TST") {}

    function mint(address owner, uint256 amount) external {
        _mint(owner, amount);
    }
}


