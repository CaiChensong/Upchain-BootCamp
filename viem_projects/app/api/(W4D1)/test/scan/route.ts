import { NextResponse } from "next/server";
import { createPublicClient, http, parseAbiItem, getAddress } from "viem";
import { sepolia } from "viem/chains";

// ERC20 Transfer 事件 ABI
const ERC20_TRANSFER_EVENT = parseAbiItem(
  "event Transfer(address indexed from, address indexed to, uint256 value)"
);

// 创建公共客户端
const publicClient = createPublicClient({
  chain: sepolia,
  transport: http("https://1rpc.io/sepolia"),
});

// 测试扫描功能
export async function GET() {
  try {
    // 使用你的 ERC20 合约地址
    const tokenAddress = "0xC044905455DBe3ba560FF064304161b9995B1898";

    // 获取当前区块
    const currentBlock = await publicClient.getBlockNumber();
    const fromBlock = Number(currentBlock) - 100; // 扫描最近100个区块

    console.log(`测试扫描区块 ${fromBlock} 到 ${currentBlock}`);

    // 构建过滤器
    const filter = {
      address: getAddress(tokenAddress),
      event: ERC20_TRANSFER_EVENT,
      fromBlock: BigInt(fromBlock),
      toBlock: currentBlock,
    };

    // 获取日志
    const logs = await publicClient.getLogs(filter);
    console.log(`找到 ${logs.length} 条转账记录`);

    // 处理前几条记录作为示例
    const sampleRecords = [];
    for (let i = 0; i < Math.min(logs.length, 5); i++) {
      const log = logs[i];

      if (log.args.from && log.args.to && log.args.value) {
        // 获取区块信息
        const block = await publicClient.getBlock({
          blockHash: log.blockHash,
        });

        sampleRecords.push({
          transaction_hash: log.transactionHash,
          from_address: log.args.from,
          to_address: log.args.to,
          amount: log.args.value.toString(),
          block_number: Number(log.blockNumber),
          token_address: tokenAddress,
          timestamp: Number(block.timestamp),
        });
      }
    }

    return NextResponse.json({
      success: true,
      message: "测试扫描完成",
      data: {
        tokenAddress,
        scannedBlocks: {
          from: fromBlock,
          to: Number(currentBlock),
        },
        totalLogs: logs.length,
        sampleRecords,
        currentBlock: Number(currentBlock),
      },
    });
  } catch (error) {
    console.error("测试扫描失败:", error);
    return NextResponse.json(
      {
        success: false,
        error: "测试扫描失败",
        message: error instanceof Error ? error.message : "未知错误",
      },
      { status: 500 }
    );
  }
}
