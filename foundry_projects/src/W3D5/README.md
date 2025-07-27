## 题目#1 使用 EIP712 进行链下 Permit 和 白名单设计

- 使用 EIP2612 标准（可基于 Openzepplin 库）编写一个自己名称的 Token 合约。
- 修改 TokenBank 存款合约，添加一个函数 permitDeposit 以支持离线签名授权（permit）进行存款, 并在 TokenBank 前端加入通过签名存款。
- 修改 Token 购买 NFT 的 NTFMarket 合约，添加功能 permitBuy() 实现只有离线授权的白名单地址才可以购买 NFT （用自己的名称发行 NFT，再上架） 。白名单具体实现逻辑为：项目方给白名单地址签名，白名单用户拿到签名信息后，传给 permitBuy() 函数，在 permitBuy() 中判断是否是经过许可的白名单用户，如果是，才可以进行后续购买，否则 revert 。

要求：

- 有 Token 存款及 NFT 购买成功的测试用例
- 有测试用例运行日志或截图，能够看到 Token 及 NFT 转移。
- 请填写你的 Github 项目链接地址。

## 题目#2 理解 Permit2 及实践

(在本地环境需要先部署 Permit2 合约)

- 在原来的 TokenBank 添加一个方法 depositWithPermit2()， 这个方式使用 permit2 进行签名授权转账来进行存款。
- 修改 Token 存款前端 让用户可以在前端通过 permit2 的签名存款。
