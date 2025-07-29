import { NextResponse } from "next/server";
import {
  insertTransferRecord,
  getTransferRecords,
  getAllTransferRecords,
} from "../db";

// GET 请求：查询转账记录
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const address = searchParams.get("address");
    const page = parseInt(searchParams.get("page") || "1");
    const limit = parseInt(searchParams.get("limit") || "10");

    // 如果没有指定地址，返回所有记录（用于测试）
    if (!address) {
      const allRecords = await getAllTransferRecords();
      return NextResponse.json({
        success: true,
        data: allRecords,
        message: "获取所有转账记录成功",
      });
    }

    // 查询指定地址的转账记录
    const result = await getTransferRecords(address, page, limit);

    return NextResponse.json({
      success: true,
      data: result.records,
      pagination: {
        page: result.page,
        limit: result.limit,
        total: result.total,
        totalPages: Math.ceil(result.total / result.limit),
      },
      message: "查询转账记录成功",
    });
  } catch (error) {
    console.error("查询转账记录失败:", error);
    return NextResponse.json(
      {
        success: false,
        error: "查询转账记录失败",
        message: error instanceof Error ? error.message : "未知错误",
      },
      { status: 500 }
    );
  }
}

// POST 请求：插入转账记录
export async function POST(request: Request) {
  try {
    const body = await request.json();

    // 验证必需字段
    const {
      transaction_hash,
      from_address,
      to_address,
      amount,
      block_number,
      token_address,
      timestamp,
    } = body;

    if (
      !transaction_hash ||
      !from_address ||
      !to_address ||
      !amount ||
      !block_number ||
      !token_address ||
      !timestamp
    ) {
      return NextResponse.json(
        {
          success: false,
          error: "缺少必需字段",
          required: [
            "transaction_hash",
            "from_address",
            "to_address",
            "amount",
            "block_number",
            "token_address",
            "timestamp",
          ],
        },
        { status: 400 }
      );
    }

    // 插入转账记录
    const result = await insertTransferRecord({
      transaction_hash,
      from_address,
      to_address,
      amount: amount.toString(),
      block_number: parseInt(block_number),
      token_address,
      timestamp: parseInt(timestamp),
    });

    return NextResponse.json({
      success: true,
      data: {
        id: result.lastID,
        transaction_hash,
        from_address,
        to_address,
        amount,
        block_number,
        token_address,
        timestamp,
      },
      message: "转账记录插入成功",
    });
  } catch (error) {
    console.error("插入转账记录失败:", error);
    return NextResponse.json(
      {
        success: false,
        error: "插入转账记录失败",
        message: error instanceof Error ? error.message : "未知错误",
      },
      { status: 500 }
    );
  }
}
