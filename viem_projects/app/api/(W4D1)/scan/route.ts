import { NextResponse } from "next/server";
import { createPublicClient, http, parseAbiItem, getAddress } from "viem";
import { sepolia } from "viem/chains";
import { insertTransferRecord } from "../db";

// ERC20 Transfer 事件 ABI
const ERC20_TRANSFER_EVENT = parseAbiItem(
  "event Transfer(address indexed from, address indexed to, uint256 value)"
);

// 创建公共客户端
const publicClient = createPublicClient({
  chain: sepolia,
  transport: http("https://1rpc.io/sepolia"),
});

// 扫描区块链上的 ERC20 转账事件
export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { tokenAddress, fromBlock, toBlock, fromAddress, toAddress } = body;

    // 验证必需字段
    if (!tokenAddress) {
      return NextResponse.json(
        {
          success: false,
          error: "缺少必需字段",
          required: ["tokenAddress"],
          optional: ["fromBlock", "toBlock", "fromAddress", "toAddress"],
        },
        { status: 400 }
      );
    }

    // 设置默认值
    const currentBlock = await publicClient.getBlockNumber();
    const scanFromBlock = fromBlock || Number(currentBlock) - 1000; // 默认扫描最近1000个区块
    const scanToBlock = toBlock || Number(currentBlock);

    console.log(`开始扫描区块 ${scanFromBlock} 到 ${scanToBlock}`);

    // 构建过滤器
    const filter = {
      address: getAddress(tokenAddress),
      event: ERC20_TRANSFER_EVENT,
      fromBlock: BigInt(scanFromBlock),
      toBlock: BigInt(scanToBlock),
      args: {
        from: fromAddress ? getAddress(fromAddress) : undefined,
        to: toAddress ? getAddress(toAddress) : undefined,
      },
    };

    // 获取日志
    const logs = await publicClient.getLogs(filter);
    console.log(`找到 ${logs.length} 条转账记录`);

    // 处理日志并插入数据库
    const insertedRecords = [];
    for (const log of logs) {
      try {
        // 验证必要字段
        if (!log.args.from || !log.args.to || !log.args.value) {
          console.warn(`跳过不完整的日志: ${log.transactionHash}`);
          continue;
        }

        // 获取区块信息
        const block = await publicClient.getBlock({
          blockHash: log.blockHash,
        });

        // 准备插入数据
        const transferData = {
          transaction_hash: log.transactionHash,
          from_address: log.args.from,
          to_address: log.args.to,
          amount: log.args.value.toString(),
          block_number: Number(log.blockNumber),
          token_address: getAddress(tokenAddress),
          timestamp: Number(block.timestamp),
        };

        // 插入数据库
        const result = await insertTransferRecord(transferData);

        insertedRecords.push({
          id: result.lastID,
          ...transferData,
        });
      } catch (error) {
        console.error(`处理交易 ${log.transactionHash} 时出错:`, error);
        // 继续处理其他记录
      }
    }

    return NextResponse.json({
      success: true,
      message: "区块链扫描完成",
      data: {
        scannedBlocks: {
          from: scanFromBlock,
          to: scanToBlock,
        },
        totalLogs: logs.length,
        insertedRecords: insertedRecords.length,
        records: insertedRecords,
      },
    });
  } catch (error) {
    console.error("扫描区块链失败:", error);
    return NextResponse.json(
      {
        success: false,
        error: "扫描区块链失败",
        message: error instanceof Error ? error.message : "未知错误",
      },
      { status: 500 }
    );
  }
}

// GET 请求：获取扫描状态和统计信息
export async function GET() {
  try {
    const currentBlock = await publicClient.getBlockNumber();

    return NextResponse.json({
      success: true,
      data: {
        currentBlock: Number(currentBlock),
        chain: sepolia.name,
        chainId: sepolia.id,
        rpcUrl: "https://1rpc.io/sepolia",
      },
      message: "获取区块链状态成功",
    });
  } catch (error) {
    console.error("获取区块链状态失败:", error);
    return NextResponse.json(
      {
        success: false,
        error: "获取区块链状态失败",
        message: error instanceof Error ? error.message : "未知错误",
      },
      { status: 500 }
    );
  }
}
