import { open } from "sqlite";
import sqlite3 from "sqlite3";
import path from "path";

// 数据库文件路径
const DB_PATH = path.join(process.cwd(), "app", "api", "(W4D1)", "sqlite.db");

// 数据库连接实例
let db: any = null;

// 获取数据库连接
export async function getDatabase(): Promise<any> {
  if (!db) {
    db = await open({
      filename: DB_PATH,
      driver: sqlite3.Database,
    });

    // 初始化表结构
    await initTables();
  }
  return db;
}

// 初始化数据库表
async function initTables() {
  const database = await getDatabase();

  // 创建转账记录表
  await database.exec(`
    CREATE TABLE IF NOT EXISTS transfer_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_hash TEXT NOT NULL,
      from_address TEXT NOT NULL,
      to_address TEXT NOT NULL,
      amount TEXT NOT NULL,
      block_number INTEGER NOT NULL,
      token_address TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  console.log("数据库表初始化完成");
}

// 插入转账记录
export async function insertTransferRecord(data: {
  transaction_hash: string;
  from_address: string;
  to_address: string;
  amount: string;
  block_number: number;
  token_address: string;
  timestamp: number;
}) {
  const database = await getDatabase();

  const result = await database.run(
    `
    INSERT INTO transfer_records (transaction_hash, from_address, to_address, amount, block_number, token_address, timestamp)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `,
    [
      data.transaction_hash,
      data.from_address,
      data.to_address,
      data.amount,
      data.block_number,
      data.token_address,
      data.timestamp,
    ]
  );

  return result;
}

// 查询转账记录
export async function getTransferRecords(
  address: string,
  page: number = 1,
  limit: number = 10
) {
  const database = await getDatabase();
  const offset = (page - 1) * limit;

  const records = await database.all(
    `
    SELECT * FROM transfer_records 
    WHERE from_address = ? OR to_address = ?
    ORDER BY timestamp DESC
    LIMIT ? OFFSET ?
  `,
    [address, address, limit, offset]
  );

  const total = await database.get(
    `
    SELECT COUNT(*) as count FROM transfer_records 
    WHERE from_address = ? OR to_address = ?
  `,
    [address, address]
  );

  return {
    records,
    total: total?.count || 0,
    page,
    limit,
  };
}

// 获取所有转账记录（用于测试）
export async function getAllTransferRecords() {
  const database = await getDatabase();

  const records = await database.all(`
    SELECT * FROM transfer_records 
    ORDER BY timestamp DESC
  `);

  return records;
}

// 关闭数据库连接
export async function closeDatabase() {
  if (db) {
    await db.close();
    db = null;
  }
}
