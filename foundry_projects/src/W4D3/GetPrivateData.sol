// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1 读取合约私有变量数据

使用 Viem 利用 getStorageAt 从链上读取 _locks 数组中的所有元素值，并打印出如下内容：
locks[0]: user:…… ,startTime:……,amount:……

贴出 GitHub 链接，其中包含运行日志
*/

contract esRNT {
    struct LockInfo {
        address user;
        uint64 startTime;
        uint256 amount;
    }

    LockInfo[] private _locks;

    constructor() {
        for (uint256 i = 0; i < 11; i++) {
            _locks.push(LockInfo(address(uint160(i + 1)), uint64(block.timestamp * 2 - i), 1e18 * (i + 1)));
        }
    }
}
