## 题目#1 编写一个可升级的 NFT Market 合约

1. 编写一个可升级的 ERC721 合约。
2. 实现⼀个可升级的 NFT 市场合约：
   - 实现合约的第⼀版本和 这个挑战 的逻辑一致。
   - 逻辑合约的第⼆版本，加⼊离线签名上架 NFT 功能⽅法（签名内容：tokenId， 价格），实现⽤户⼀次性使用 setApproveAll 给 NFT 市场合约，每个 NFT 上架时仅需使⽤签名上架。
3. 部署到测试⽹，并开源到区块链浏览器，在你的 Github 的 Readme.md 中备注代理合约及两个实现的合约地址。

要求：

- 包含升级的测试用例（升级前后的状态保持一致）
- 包含运行测试用例的日志。

请提交你的 Github 仓库地址。

## Answer

### 测试流程

- 首先使用 shell 脚本部署相关合约
  - 脚本位置：foundry_projects/src/W5D1/deploy_upgradeable_contracts.sh
  - 脚本运行日志：foundry_projects/src/W5D1/DeployLog.txt
- 然后使用 TS 脚本测试 V1 合约，升级合约，以及测试 V2 合约
  - 脚本位置：viem_projects/app/(W5D1)/upgradeable-contract.ts
  - 脚本运行日志：viem_projects/app/(W5D1)/testUpgradeableContractsLog.txt

### 相关合约代码位置和部署地址：

ERC20 Token 合约

- 代码：foundry_projects/src/W2D4/MyToken.sol
- 地址：https://sepolia.etherscan.io/address/0xc044905455dbe3ba560ff064304161b9995b1898

UpgradeableNFTV1 合约

- 代码：foundry_projects/src/W5D1/UpgradeableNFT.sol
- 地址：https://sepolia.etherscan.io/address/0xBaf737945cb17348C5F603d9F6E618302A5143e0

UpgradeableNFTV2 合约

- 代码：foundry_projects/src/W5D1/UpgradeableNFT.sol
- 地址：https://sepolia.etherscan.io/address/0x9A895f01782B181f45E3ca7C6BE9Bb5f4e213CFa

UpgradeableNFT 代理合约

- 代码：foundry_projects/lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol
- 地址：https://sepolia.etherscan.io/address/0xDad4CbAEEf52420B4e57510097e76badE42301bE

UpgradeableNFTMarketV1 合约

- 代码：foundry_projects/src/W5D1/UpgradeableNFTMarket.sol
- 地址：https://sepolia.etherscan.io/address/0xd4783f3eD1C6B832553137597408292Fe4F21636

UpgradeableNFTMarketV2 合约

- 代码：foundry_projects/src/W5D1/UpgradeableNFTMarket.sol
- 地址：https://sepolia.etherscan.io/address/0x5d547f9d1ad7E1132B5295E08c1E614e65716f8F

UpgradeableNFTMarket 代理合约

- 代码：foundry_projects/lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol
- 地址：https://sepolia.etherscan.io/address/0x92C5Eb78B93DE6b78e9d24a40bf7e6c34cB199e8
