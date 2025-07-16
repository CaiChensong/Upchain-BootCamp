// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
题目#1

扩展 ERC20 合约 ，添加一个有 hook 功能的转账函数，如函数名为：transferWithCallback ，在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法。

继承 TokenBank 编写 TokenBankV2，支持存入扩展的 ERC20 Token，用户可以直接调用 transferWithCallback 将 扩展的 ERC20 Token 存入到 TokenBankV2 中。

（备注：TokenBankV2 需要实现 tokensReceived 来实现存款记录工作）
*/

import {BaseERC20} from "W2D1/ERC20.sol";
import {TokenBank} from "W2D1/TokenBank.sol";

interface Receiver {
    function tokensReceived(
        address sender,
        uint256 value,
        bytes calldata data
    ) external returns (bool);
}

contract ERC20Extend is BaseERC20 {

    function transferWithCallback(address to, uint amount) external returns (bool) {
        transfer(to, amount);

        if (to.code.length > 0) {
            bool rv = Receiver(to).tokensReceived(msg.sender, amount, "");
            require(rv, "No tokensReceived");
        }

        return true;
    }
}

contract TokenBankV2 is TokenBank, Receiver {

    constructor(address _token) TokenBank(_token) {}

    function tokensReceived(
        address sender,
        uint256 value,
        bytes calldata data
    ) external returns (bool) {
        require(token == msg.sender, "not autherized address");
        balances[sender] += value;
        return true;
    }
}
