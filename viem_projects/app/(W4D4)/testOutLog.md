### 脚本使用方法：

- 先启动本地节点，并部署合约

```shell
forge script --broadcast --rpc-url "http://127.0.0.1:8545" --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 script/W4D4/AirdopMerkleNFTMarket.s.sol:AirdopMerkleNFTMarketScript
```

- 然后运行脚本

```shell
npx tsx app/\(W4D4\)/airdrop_merkle_nft_market.ts
```

### 脚本运行日志：

```shell
开始测试 AirdopMerkleNFTMarket 合约的 multicall 方法

开始准备工作...

1. 检查买家代币余额...
买家当前余额: 1000000000000000000000 wei

2. 检查卖家余额和NFT...
卖家当前余额: 1000000000000000000000 wei

3. 铸造NFT给卖家...
当前NFT总供应量: 2

4. 检查NFT上架状态...
NFT 0 上架状态: 所有者=0x70997970C51812dc3A010C7d01b50e0d17dc79C8, 价格=100000000000000000000, 激活=true

5. 设置默克尔根...
默克尔根设置成功，交易哈希: 0xea1d77d3817b28ce97fb20f4ad88c0c52f9600127d9f45bf9dcd3eb348f504bd
默克尔根: 1d2c6d0de38c77d2a15f6d241121ec032404625e87566d8a742d3dc2f924263d

准备工作完成！
开始测试 multicall 方法...

1. 取用户1的证明...
用户1的证明: [
  '0x1ebaa930b8e9130423c183bf38b0564b0103180b7dad301013b18e59880541ae',
  '0xf4ca8532861558e29f9858a3804245bb30f0303cc71e4192e41546237b6ce58b'
]

2. 生成 permit 签名...
Permit 签名生成完成

3. 准备 multicall 数据...

4. 执行 multicall...
Multicall 交易已发送，哈希: 0xc0082fc84189acb3130f5febacd8dfb5ab39d0e8ba4d4b5741337b43944a1b2d

5. 等待交易确认...
交易已确认，区块号: 14n

6. 解析 multicall 结果...
找到市场合约事件: {
  address: '0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0',
  topics: [
    '0x3faa0fa0e2828ac746d62a3e3e65d92a667f9e0cda97211d7591ac587045aba6',
    '0x0000000000000000000000000000000000000000000000000000000000000000',
    '0x0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc',
    '0x00000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c8'
  ],
  data: '0x000000000000000000000000e7f1725e7734ce288f8367e1bb143e90bb3f0512000000000000000000000000000000000000000000000002b5e3af16b1880000',
  blockHash: '0x5789ed97f4935e00559cd8c3d5390fa0b6c188aa4dd285627acc239d09bbb247',
  blockNumber: 14n,
  blockTimestamp: '0x688b7d0b',
  transactionHash: '0xc0082fc84189acb3130f5febacd8dfb5ab39d0e8ba4d4b5741337b43944a1b2d',
  transactionIndex: 0,
  logIndex: 3,
  removed: false
}

Multicall 测试完成！
```
