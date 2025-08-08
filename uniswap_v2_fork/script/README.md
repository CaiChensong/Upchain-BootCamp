## 部署指南

> 注意：
>
> - 由于 Uniswap V2 的 Solidity 版本较低，在本地部署时需要修改部分编译错误（本项目已修改）。
> - [UniswapV2Library.sol](.src/v2-periphery/libraries/UniswapV2Library.sol) 中的 `pairFor()` 方法使用了固定的 init code hash，但是由于本地编译器版本不同，该编码会出现变化，参考[这篇文章](https://learnblockchain.cn/article/8887)。
> - 本项目对于 init code hash 问题的解决办法：在 [UniswapV2Factory.sol](./src/v2-core/UniswapV2Factory.sol) 合约中增加 `getInitCodePairHash()` 方法来获取当前的 init code hash，并在 `pairFor()` 方法中调用。

### 环境准备

1. **安装 Foundry**

   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **设置私钥**

   ```bash
   export PRIVATE_KEY=your_private_key_here
   ```

   或创建配置文件:

   ```bash
   cp deploy.config.example deploy.config
   # 编辑deploy.config文件，填入你的私钥和RPC URL
   ```

### 部署步骤

1. **构建项目**

   ```bash
   forge build
   ```

2. **本地部署 (Anvil)**

   ```bash
   # 启动本地网络
   anvil

   # 在另一个终端部署合约
   forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
   ```

3. **测试网部署 (Sepolia)**

   ```bash
   # 加载环境变量
   source deploy.config

   # 部署合约
   forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
   ```

### 快速部署

一键本地部署:

```bash
# 设置私钥 (替换为你的私钥)
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 启动anvil并部署
anvil & sleep 2 && forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

### 部署的合约

部署脚本会输出以下合约地址:

- **WETH9**: Wrapped Ether 代币合约
- **Factory**: 工厂合约，用于创建交易对
- **Router**: 路由合约，提供交易接口

### 使用示例

部署完成后，你可以:

1. **创建交易对**

   ```solidity
   factory.createPair(tokenA, tokenB);
   ```

2. **添加流动性**

   ```solidity
   router.addLiquidity(
       tokenA, tokenB,
       amountADesired, amountBDesired,
       amountAMin, amountBMin,
       to, deadline
   );
   ```

3. **交换代币**
   ```solidity
   router.swapExactTokensForTokens(
       amountIn, amountOutMin,
       path, to, deadline
   );
   ```
