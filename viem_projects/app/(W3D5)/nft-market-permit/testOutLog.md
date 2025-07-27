测试前准备工作：

- 启动本地测试网，并使用 `script/W3D5/NFTMarketPermit.s.sol` 部署相关合约
- 使用命令 `npx tsx app/\(W3D5\)/nft-market-permit/index.ts` 启动测试脚本

测试脚本输出内容如下：

```shell
=== NFTMarket PermitBuy 测试开始 ===
卖家余额: 0 wei
买家余额: 0 wei

--- 转账Token给卖家 ---
Token转账成功，交易哈希: 0x2cf424a228f43f6497434bc79d09d87d4d851b32079782e846ade23880d3e4b3

--- 转账Token给买家 ---
Token转账成功，交易哈希: 0x50d5a52103deef435598f6d69b53105a6db3c64dd6be986dbc6fa34ea863b933

--- 铸造NFT ---
NFT铸造成功，交易哈希: 0xe1fb06bb188e647c0b6dfb246261224750f1953f39c94b334eba31b4672a4f6b
NFT铸造成功，所有者: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8

--- 授权NFT市场合约 ---
NFT授权成功，交易哈希: 0xc0e2880f871abbc03e5373160f5e24cee2fa4746fa3eee5132193cbc038f5308

--- 上架NFT ---
NFT上架成功，交易哈希: 0x723b6721aff712787e962f5f83d7b008ae9953f1635839ffae6bb7fafa4e0e48
NFT上架成功，价格: 100000000000000000000 wei

--- 生成签名 ---
签名生成成功

--- 授权Token ---
Token授权成功，交易哈希: 0x80d6ad21d1dc787d21d8934c76f085b4f563b6469e996e2dd164097abd70d239

--- 执行permitBuy ---
permitBuy执行成功，交易哈希: 0x227a9106746ce3156d701dedc4f67c5aa870a2899af7aababff500b2d8c816eb

--- 验证结果 ---
NFT新所有者: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
购买成功: true

--- 测试非白名单用户 ---
非白名单用户购买失败（符合预期）

=== 测试完成 ===
```
