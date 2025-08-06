## 题目#1 安全挑战：Hack Vault

Fork 代码库：
https://github.com/OpenSpace100/openspace_ctf

阅读代码 Vault.sol 及测试用例，在测试用例中 testExploit 函数添加一些代码，设法取出预先部署的 Vault 合约内的所有资金。
以便运行 forge test 可以通过所有测试。

可以在 Vault.t.sol 中添加代码，或加入新合约，但不要修改已有代码。

请提交你 fork 后的代码库链接。

## Answer

相关实现在：foundry_projects/test/W5D2/Vault.t.sol

注意点：

- 当通过 delegatecall 调用 VaultLogic.changeOwner 时，VaultLogic 合约中的 password 变量存储槽对应的是 Vault 合约的 slot 1，即 logic 地址。所以我们可以直接使用 logic 地址作为密码，修改 owner 为我们自己的账户。
- 提取资金则使用重入攻击，使用单独重入攻击合约实现。

Vault 仓库代码很少，为了方便管理，直接将相关代码复制到本项目中。相关代码位置映射如下：

- Vault.sol
  src/Vault.sol -> foundry_projects/src/W5D2/Vault.sol
- Vault.s.sol
  script/Vault.s.sol -> foundry_projects/script/W5D2/Vault.s.sol
- Vault.t.sol
  test/Vault.t.sol -> foundry_projects/test/W5D2/Vault.t.sol
