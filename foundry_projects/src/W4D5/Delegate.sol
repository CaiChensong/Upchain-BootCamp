// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1 EIP 7702实践：发起打包交易

- 部署自己的 Delegate 合约（需支持批量执行）到 Sepolia。
- 修改之前的 TokenBank 前端页面，让用户能够通过 EOA 账户授权给 Delegate 合约，并在一个交易中完成授权和存款操作。

提交 GitHub 代码和测试网交易的浏览器链接
*/

contract Delegate {
    event CallExecuted(address indexed caller, uint256 indexed value, bytes callData);

    receive() external payable {}
    fallback() external payable {}

    struct Call {
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    function batchExecute(Call[] calldata calls) public returns (Result[] memory returnData) {
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call calldata call_i;

        for (uint256 i = 0; i < length; i++) {
            Result memory result = returnData[i];
            call_i = calls[i];
            (result.success, result.returnData) = call_i.target.call(call_i.callData);
            if (!(call_i.allowFailure || result.success)) {
                revert("BatchExecute failed");
            }
        }
    }
}
