#!/bin/bash

# LaunchPad 本地部署脚本
# 用于在本地测试网中部署 Uniswap 和 LaunchPad 相关合约

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
LOCAL_RPC_URL="http://127.0.0.1:8545"
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
CHAIN_ID=31337

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  LaunchPad 本地部署脚本${NC}"
echo -e "${BLUE}================================${NC}"

# 检查测试网是否运行
echo -e "${YELLOW}检查本地测试网状态...${NC}"
if ! curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    $LOCAL_RPC_URL > /dev/null 2>&1; then
    echo -e "${RED}错误: 本地测试网 ($LOCAL_RPC_URL) 未运行${NC}"
    echo -e "${YELLOW}请先启动 Anvil 测试网:${NC}"
    echo -e "${BLUE}  anvil${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 本地测试网运行正常${NC}"

# 获取当前目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FOUNDRY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UNISWAP_ROOT="$(cd "$FOUNDRY_ROOT/../uniswap_v2_fork" && pwd)"

echo -e "${YELLOW}项目路径:${NC}"
echo -e "  Foundry: $FOUNDRY_ROOT"
echo -e "  Uniswap: $UNISWAP_ROOT"

# 检查必要文件是否存在
if [[ ! -f "$UNISWAP_ROOT/script/Deploy.s.sol" ]]; then
    echo -e "${RED}错误: 找不到 Uniswap 部署脚本${NC}"
    exit 1
fi

if [[ ! -f "$FOUNDRY_ROOT/script/W5D4/DeployLaunchPad.s.sol" ]]; then
    echo -e "${RED}错误: 找不到 LaunchPad 部署脚本${NC}"
    exit 1
fi

# 第一步：部署 Uniswap 合约
echo -e "\n${BLUE}================================${NC}"
echo -e "${BLUE}  步骤 1: 部署 Uniswap 合约${NC}"
echo -e "${BLUE}================================${NC}"

cd "$UNISWAP_ROOT"

# 设置环境变量
export PRIVATE_KEY=$PRIVATE_KEY

echo -e "${YELLOW}正在部署 Uniswap 合约...${NC}"
UNISWAP_OUTPUT=$(forge script script/Deploy.s.sol \
    --rpc-url $LOCAL_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    2>&1)

echo "$UNISWAP_OUTPUT"

# 从输出中提取 Router 地址
ROUTER_ADDRESS=$(echo "$UNISWAP_OUTPUT" | grep "Router deployed to:" | awk '{print $4}')

if [[ -z "$ROUTER_ADDRESS" || "$ROUTER_ADDRESS" == "0x0000000000000000000000000000000000000000" ]]; then
    echo -e "${RED}错误: 无法获取 Router 地址${NC}"
    echo -e "${YELLOW}部署输出:${NC}"
    echo "$UNISWAP_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✓ Uniswap 合约部署成功${NC}"
echo -e "  Router 地址: ${GREEN}$ROUTER_ADDRESS${NC}"

# 第二步：部署 LaunchPad 合约
echo -e "\n${BLUE}================================${NC}"
echo -e "${BLUE}  步骤 2: 部署 LaunchPad 合约${NC}"
echo -e "${BLUE}================================${NC}"

cd "$FOUNDRY_ROOT"

# 设置环境变量
export PRIVATE_KEY=$PRIVATE_KEY
export UNISWAP_V2_ROUTER=$ROUTER_ADDRESS

echo -e "${YELLOW}正在部署 LaunchPad 合约...${NC}"
echo -e "  使用 Router 地址: ${BLUE}$ROUTER_ADDRESS${NC}"

LAUNCHPAD_OUTPUT=$(forge script script/W5D4/DeployLaunchPad.s.sol \
    --rpc-url $LOCAL_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    2>&1)

echo "$LAUNCHPAD_OUTPUT"

# 从输出中提取 LaunchPad 地址
LAUNCHPAD_ADDRESS=$(echo "$LAUNCHPAD_OUTPUT" | grep "MemeLaunchPad deployed to:" | awk '{print $4}')

if [[ -z "$LAUNCHPAD_ADDRESS" || "$LAUNCHPAD_ADDRESS" == "0x0000000000000000000000000000000000000000" ]]; then
    echo -e "${RED}错误: 无法获取 LaunchPad 地址${NC}"
    echo -e "${YELLOW}部署输出:${NC}"
    echo "$LAUNCHPAD_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✓ LaunchPad 合约部署成功${NC}"

# 部署总结
echo -e "\n${BLUE}================================${NC}"
echo -e "${BLUE}     部署完成！${NC}"
echo -e "${BLUE}================================${NC}"

# 从 Uniswap 输出中提取其他地址
WETH_ADDRESS=$(echo "$UNISWAP_OUTPUT" | grep "WETH9 deployed to:" | awk '{print $4}')
FACTORY_ADDRESS=$(echo "$UNISWAP_OUTPUT" | grep "Factory deployed to:" | awk '{print $4}')

echo -e "${GREEN}合约地址:${NC}"
echo -e "  WETH9:        ${YELLOW}$WETH_ADDRESS${NC}"
echo -e "  Factory:      ${YELLOW}$FACTORY_ADDRESS${NC}"
echo -e "  Router:       ${YELLOW}$ROUTER_ADDRESS${NC}"
echo -e "  LaunchPad:    ${YELLOW}$LAUNCHPAD_ADDRESS${NC}"

echo -e "\n${GREEN}网络信息:${NC}"
echo -e "  RPC URL:      ${BLUE}$LOCAL_RPC_URL${NC}"
echo -e "  Chain ID:     ${BLUE}$CHAIN_ID${NC}"

echo -e "\n${GREEN}部署完成！${NC}"
