// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract CloudToken is ERC20, Ownable {

    mapping (address => uint256) balances; 

    mapping (address => mapping (address => uint256)) allowances; 

  
    constructor() ERC20("CloudToken", "CT") Ownable(msg.sender){
        _mint(msg.sender, 1000000 * 10 ** decimals()); // 初始发行 1000000 个 Token
    }

    function transfer(address _to, uint256 _value) public  override returns (bool success) {
        // write your code here
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true; 
    }


    function balanceOf(address account) public override view returns (uint256){
        // write your code here        
        return balances[account];
    } 

    function approve(address _spender, uint256 _value) public override returns (bool success) {
        // write your code here
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value); 
        return true; 
    }

    function allowance(address _owner, address _spender) public view override returns (uint256 remaining) {   
        // write your code here     
        return allowances[_owner][_spender];
    }
}