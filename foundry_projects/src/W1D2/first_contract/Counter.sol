//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
创建和部署第一个智能合约

使用 Remix 创建一个 Counter 合约并部署到任意以太坊测试网:

Counter 合约具有：
    - 一个状态变量 counter
    - get()方法: 获取 counter 的值
    - add(x) 方法: 给变量加上 x 

请在回答框内提交调用 add(x) 的交易 Hash 的区块链浏览器的 URL。
*/
contract Counter {
    uint256 public counter;

    function get() public view returns (uint256) {
        return counter;
    }

    function add(uint256 x) public {
        counter += x;
    }
}
