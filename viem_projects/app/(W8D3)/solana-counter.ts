import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  LAMPORTS_PER_SOL,
  Commitment,
} from "@solana/web3.js";
import { Program, AnchorProvider } from "@coral-xyz/anchor";
import { Counter } from "./counter";
import idl from "./counter.json";
import fs from "fs";

/*
题目#1 编写脚本调用 Solana 链上程序

使用脚本调用计数器程序。

最好在 本地 Anchor 环境中重新构建计数器程序， 以便自动生成 IDL 和 类型。

请贴出代码和运行截图
*/

// 配置常量
const CONFIG = {
  RPC_URL: "http://127.0.0.1:8899",
  COMMITMENT: "confirmed" as Commitment,
  AIRDROP_AMOUNT: 10 * LAMPORTS_PER_SOL, // 10 SOL
  MIN_BALANCE: LAMPORTS_PER_SOL, // 1 SOL
} as const;

// 本地测试网络连接
const connection = new Connection(CONFIG.RPC_URL, CONFIG.COMMITMENT);

// 创建测试钱包（用于签名交易）
const wallet = Keypair.generate();

// 创建Anchor Provider
const provider = new AnchorProvider(
  connection,
  {
    publicKey: wallet.publicKey,
    signTransaction: async (tx: any) => {
      tx.sign(wallet);
      return tx;
    },
    signAllTransactions: async (txs: any[]) => {
      txs.forEach((tx: any) => tx.sign(wallet));
      return txs;
    },
  },
  { commitment: CONFIG.COMMITMENT }
);

// 创建程序实例
const program = new Program<Counter>(idl as Counter, provider);

// 生成Counter账户的PDA（Program Derived Address）
function getCounterPDA(): [PublicKey, number] {
  return PublicKey.findProgramAddressSync(
    [Buffer.from("counter"), wallet.publicKey.toBuffer()],
    program.programId
  );
}

// 检查网络连接
async function checkConnection(): Promise<boolean> {
  try {
    const version = await connection.getVersion();
    console.log("Solana网络连接正常，版本:", version);
    return true;
  } catch (error) {
    console.error("Solana网络连接失败:", error);
    return false;
  }
}

// 获取账户余额
export async function getBalance(): Promise<number> {
  try {
    const balance = await connection.getBalance(wallet.publicKey);
    console.log("钱包余额:", (balance / LAMPORTS_PER_SOL).toFixed(4), "SOL");
    return balance;
  } catch (error) {
    console.error("获取余额失败:", error);
    throw error;
  }
}

// 请求空投（用于测试）
export async function requestAirdrop(): Promise<string> {
  try {
    console.log("正在请求空投...");

    const { blockhash, lastValidBlockHeight } =
      await connection.getLatestBlockhash();

    const signature = await connection.requestAirdrop(
      wallet.publicKey,
      CONFIG.AIRDROP_AMOUNT
    );

    // 等待确认
    await connection.confirmTransaction({
      signature,
      blockhash,
      lastValidBlockHeight,
    });

    console.log("空投成功！交易签名:", signature);
    return signature;
  } catch (error) {
    console.error("空投失败:", error);
    throw error;
  }
}

// 初始化Counter账户
export async function initializeCounter(): Promise<string> {
  try {
    console.log("正在初始化Counter账户...");

    // 获取Counter账户的PDA
    const [counterPda, bump] = getCounterPDA();
    console.log("Counter PDA地址:", counterPda.toString());
    console.log("Bump种子:", bump);

    // 创建初始化指令
    const tx = await program.methods
      .initialize()
      .accountsPartial({
        counter: counterPda,
        signer: wallet.publicKey,
      })
      .rpc();

    console.log("Counter账户初始化成功！");
    console.log("交易签名:", tx);

    return tx;
  } catch (error) {
    console.error("初始化Counter账户失败:", error);
    throw error;
  }
}

// 递增Counter值
export async function incrementCounter(): Promise<string> {
  try {
    console.log("正在递增Counter值...");

    // 获取Counter账户的PDA
    const [counterPda] = getCounterPDA();

    // 创建递增指令
    const tx = await program.methods
      .increment()
      .accountsPartial({
        counter: counterPda,
        signer: wallet.publicKey,
      })
      .rpc();

    console.log("Counter值递增成功！");
    console.log("交易签名:", tx);

    return tx;
  } catch (error) {
    console.error("递增Counter值失败:", error);
    throw error;
  }
}

// 查询Counter值
export async function getCounterValue(): Promise<number> {
  try {
    console.log("正在查询Counter值...");

    // 获取Counter账户的PDA
    const [counterPda] = getCounterPDA();

    // 查询账户数据
    const counterAccount = await program.account.counter.fetch(counterPda);
    const count = counterAccount.count.toNumber();

    console.log("当前Counter值:", count);

    return count;
  } catch (error) {
    console.error("查询Counter值失败:", error);
    throw error;
  }
}

// 检查Counter账户是否存在
export async function checkCounterAccount(): Promise<boolean> {
  try {
    const [counterPda] = getCounterPDA();
    const accountInfo = await connection.getAccountInfo(counterPda);
    return accountInfo !== null;
  } catch (error) {
    return false;
  }
}

// 获取交易详情
export async function getTransactionDetails(signature: string): Promise<void> {
  try {
    const transaction = await connection.getTransaction(signature, {
      maxSupportedTransactionVersion: 0,
    });

    if (transaction) {
      console.log("交易详情:");
      console.log("  - 区块高度:", transaction.slot);
      console.log("  - 费用:", transaction.meta?.fee, "lamports");
    }
  } catch (error) {
    console.error("获取交易详情失败:", error);
  }
}

// 主函数 - 演示完整的Counter程序使用流程
export async function main() {
  try {
    console.log("=== Solana Counter 程序演示 ===");
    console.log("钱包地址:", wallet.publicKey.toString());
    console.log("网络:", CONFIG.RPC_URL);
    console.log("程序ID:", program.programId);
    console.log("");

    // 检查网络连接
    const isConnected = await checkConnection();
    if (!isConnected) {
      throw new Error("无法连接到Solana网络");
    }

    // 检查余额，如果不足则请求空投
    const balance = await getBalance();
    if (balance < CONFIG.MIN_BALANCE) {
      console.log("余额不足，请求空投...");
      await requestAirdrop();
      await getBalance();
    }

    // 检查Counter账户是否已存在
    const accountExists = await checkCounterAccount();
    if (!accountExists) {
      console.log("Counter账户不存在，开始初始化...");
      // 初始化Counter账户
      const initTx = await initializeCounter();
      await getTransactionDetails(initTx);
    } else {
      console.log("Counter账户已存在，跳过初始化");
    }

    // 查询当前值
    const currentValue = await getCounterValue();

    // 递增Counter值
    const incrementTx = await incrementCounter();
    await getTransactionDetails(incrementTx);

    // 查询新值
    const newValue = await getCounterValue();
    console.log("递增完成: ", currentValue, " → ", newValue);

    // 再次递增
    const incrementTx2 = await incrementCounter();
    await getTransactionDetails(incrementTx2);

    // 最终查询
    const finalValue = await getCounterValue();
    console.log("最终Counter值:", finalValue);

    console.log("=== 演示完成 ===");
  } catch (error) {
    console.error("演示过程中发生错误:", error);
    process.exit(1);
  }
}

// 如果直接运行此文件，则执行主函数
if (require.main === module) {
  main().catch((error) => {
    console.error("程序执行失败:", error);
    process.exit(1);
  });
}
