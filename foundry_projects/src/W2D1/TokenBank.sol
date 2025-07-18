// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
Solidity 编写 TokenBank

编写一个 TokenBank 合约，可以将自己的 ERC20 Token 存入到 TokenBank， 和从 TokenBank 取出。

TokenBank 有两个方法：

- deposit(): 需要记录每个地址的存入数量；
- withdraw(): 用户可以提取自己的之前存入的 token。
*/

import "./ERC20.sol";

contract TokenBank {

    address public token;
    mapping(address => uint256) public balances;

    constructor(address _token) {
        token = _token;
    }

    function deposit(uint256 value) public payable {
        require(BaseERC20(token).transferFrom(msg.sender, address(this), value), "Transfer failed");
        balances[msg.sender] += value;
    }

    function withdraw(uint256 value) public {
        require (value <= balances[msg.sender], "Token balance is not enough");

        require(BaseERC20(token).transfer(msg.sender, value), "Transfer failed");
        balances[msg.sender] -= value;
    }
}

