import { NextResponse } from "next/server";
import {
  insertTransferRecord,
  getAllTransferRecords,
  getDatabase,
} from "../../db";

// GET 请求：获取所有记录并插入测试数据
export async function GET() {
  try {
    // 插入一些测试数据
    const testData = [
      {
        transaction_hash:
          "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
        from_address: "0x1234567890123456789012345678901234567890",
        to_address: "0x0987654321098765432109876543210987654321",
        amount: "1000000000000000000", // 1 token (18 decimals)
        block_number: 12345678,
        token_address: "0xC044905455DBe3ba560FF064304161b9995B1898",
        timestamp: Math.floor(Date.now() / 1000) - 3600, // 1小时前
      },
      {
        transaction_hash:
          "0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321",
        from_address: "0x0987654321098765432109876543210987654321",
        to_address: "0x1234567890123456789012345678901234567890",
        amount: "500000000000000000", // 0.5 token
        block_number: 12345679,
        token_address: "0xC044905455DBe3ba560FF064304161b9995B1898",
        timestamp: Math.floor(Date.now() / 1000) - 1800, // 30分钟前
      },
    ];

    // 插入测试数据
    for (const data of testData) {
      await insertTransferRecord(data);
    }

    // 获取所有记录
    const allRecords = await getAllTransferRecords();

    return NextResponse.json({
      success: true,
      message: "测试数据插入成功",
      insertedCount: testData.length,
      allRecords: allRecords,
    });
  } catch (error) {
    console.error("测试数据库失败:", error);
    return NextResponse.json(
      {
        success: false,
        error: "测试数据库失败",
        message: error instanceof Error ? error.message : "未知错误",
      },
      { status: 500 }
    );
  }
}

// POST 请求：清空数据库（仅用于测试）
export async function POST() {
  try {
    const database = await getDatabase();

    // 删除所有记录
    await database.run("DELETE FROM transfer_records");

    return NextResponse.json({
      success: true,
      message: "数据库已清空",
    });
  } catch (error) {
    console.error("清空数据库失败:", error);
    return NextResponse.json(
      {
        success: false,
        error: "清空数据库失败",
        message: error instanceof Error ? error.message : "未知错误",
      },
      { status: 500 }
    );
  }
}
