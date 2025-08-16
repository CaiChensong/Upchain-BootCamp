## 题目#1 实现基于 Token 投票治理

1. 先实现一个可以可计票的 Token
2. 实现一个通过 DAO 管理 Bank 的资金使用：
   - Bank 合约中有提取资金 withdraw()，该方法仅管理员可调用。
   - 治理 Gov 合约作为 Bank 管理员, Gov 合约使用 Token 投票来执行相应的动作。
   - 通过发起提案从 Bank 合约资金，实现管理 Bank 的资金。

除合约代码外，需要有完成的提案、投票、执行的测试用例。请贴出你的 github 链接。

## Answer

相关合约代码：

- VoteToken: foundry_projects/src/W6D5/VoteToken.sol
- Gov: foundry_projects/src/W6D5/Gov.sol
- Timelock: foundry_projects/src/W6D5/Timelock.sol
- DaoBank: foundry_projects/src/W6D5/DaoBank.sol

测试代码和结果：

- foundry_projects/test/W6D5/DaoTest.t.sol
- foundry_projects/test/W6D5/TestLog.txt

参考代码：https://github.com/compound-finance/compound-protocol/tree/master/contracts
