#!/bin/bash

# 部署可升级合约
# 使用 Foundry 在本地 Anvil 网络中进行部署
# 支持本地 Anvil 和 Sepolia 测试网
#
# 使用方法:
# 1. 设置环境变量:
#    export PRIVATE_KEY=your_private_key_here
#
# 2. 运行脚本:
#    bash src/W5D1/deploy_upgradeable_contracts.sh
#
# 注意: 请确保私钥安全，不要将其提交到版本控制系统中

# 配置参数

# RPC_URL=${RPC_URL:-"http://127.0.0.1:8545"}
# ADMIN_ADDRESS=${ADMIN_ADDRESS:-"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"}

RPC_URL=${RPC_URL:-"https://sepolia.infura.io/v3/53a58eac66a04d69bd2577334f365651"}
ADMIN_ADDRESS=${ADMIN_ADDRESS:-"0x91c035258B5a3B13211A74726d72090734E5BF4a"}

# 检查必要的环境变量
if [ -z "$PRIVATE_KEY" ]; then
    echo "错误: 未设置 PRIVATE_KEY 环境变量"
    echo "请设置环境变量: export PRIVATE_KEY=your_private_key_here"
    exit 1
fi

echo "=== 开始部署可升级合约 ==="
echo "RPC URL: $RPC_URL"
echo "管理员地址: $ADMIN_ADDRESS"

echo "1. 编译合约..."
forge build

echo "2. 部署 Token 合约..."
# 使用 script 部署 Token 合约
# TOKEN_DEPLOY_OUTPUT=$(forge script script/W2D4/MyToken.s.sol:MyTokenScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast)

# 从部署输出中提取 Token 合约地址
# TOKEN_ADDRESS=$(echo "$TOKEN_DEPLOY_OUTPUT" | grep "MyToken deployed at:" | tail -1 | awk '{print $NF}')

TOKEN_ADDRESS=0xc044905455dbe3ba560ff064304161b9995b1898
echo "Token 合约地址: $TOKEN_ADDRESS"

echo "3. 使用 Script 部署 V1 实现合约..."
# 使用 script 部署 V1 实现合约并获取地址
DEPLOY_OUTPUT=$(forge script script/W5D1/UpgradeableContract.s.sol:UpgradeableContractV1 --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify)

# 从部署输出中提取合约地址
NFT_V1_IMPL=$(echo "$DEPLOY_OUTPUT" | grep "UpgradeableNFTV1 deployed at:" | tail -1 | awk '{print $NF}')
MARKET_V1_IMPL=$(echo "$DEPLOY_OUTPUT" | grep "UpgradeableNFTMarketV1 deployed at:" | tail -1 | awk '{print $NF}')

echo "NFT V1 实现合约地址: $NFT_V1_IMPL"
echo "Market V1 实现合约地址: $MARKET_V1_IMPL"

echo "4. 部署代理合约..."
# 创建初始化数据
NFT_INIT_DATA=$(cast calldata "initialize(address)" $ADMIN_ADDRESS)
MARKET_INIT_DATA=$(cast calldata "initialize(address)" $TOKEN_ADDRESS)

# 部署代理合约
echo "部署 NFT 代理合约..."
NFT_PROXY_OUTPUT=$(forge create --broadcast --rpc-url $RPC_URL --private-key $PRIVATE_KEY lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy --constructor-args $NFT_V1_IMPL $ADMIN_ADDRESS $NFT_INIT_DATA)
NFT_PROXY=$(echo "$NFT_PROXY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
echo "NFT 代理合约地址: $NFT_PROXY"

echo "部署 Market 代理合约..."
MARKET_PROXY_OUTPUT=$(forge create --broadcast --rpc-url $RPC_URL --private-key $PRIVATE_KEY lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy --constructor-args $MARKET_V1_IMPL $ADMIN_ADDRESS $MARKET_INIT_DATA)
MARKET_PROXY=$(echo "$MARKET_PROXY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
echo "Market 代理合约地址: $MARKET_PROXY"

echo "5. 使用 Script 部署 V2 实现合约..."
# 使用 script 部署 V2 合约并获取地址
DEPLOY_V2_OUTPUT=$(forge script script/W5D1/UpgradeableContract.s.sol:UpgradeableContractV2 --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify)

# 从部署输出中提取 V2 合约地址
NFT_V2_IMPL=$(echo "$DEPLOY_V2_OUTPUT" | grep "UpgradeableNFTV2 deployed at:" | tail -1 | awk '{print $NF}')
MARKET_V2_IMPL=$(echo "$DEPLOY_V2_OUTPUT" | grep "UpgradeableNFTMarketV2 deployed at:" | tail -1 | awk '{print $NF}')

echo "NFT V2 实现合约地址: $NFT_V2_IMPL"
echo "Market V2 实现合约地址: $MARKET_V2_IMPL"

echo "=== 部署完成 ==="

echo "合约地址总结："
echo "Token 合约: $TOKEN_ADDRESS"
echo "NFT V1 实现: $NFT_V1_IMPL"
echo "NFT V2 实现: $NFT_V2_IMPL"
echo "NFT 代理: $NFT_PROXY"
echo "Market V1 实现: $MARKET_V1_IMPL"
echo "Market V2 实现: $MARKET_V2_IMPL"
echo "Market 代理: $MARKET_PROXY"

echo "=== 部署脚本执行完成 ==="
