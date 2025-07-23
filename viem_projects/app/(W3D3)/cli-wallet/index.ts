/*
题目#1 使用 Viem 构建一个 CLI 钱包

编写一个脚本（可以基于 Viem.js 、Ethers.js 或其他的库来实现）来模拟一个命令行钱包，钱包包含的功能有：

- 生成私钥、查询余额（可人工转入金额）
- 构建一个 ERC20 转账的 EIP 1559 交易
- 用第一步生成的账号，对 ERC20 转账进行签名
- 发送交易到 Sepolia 网络

提交代码仓库以及自己构造交易的浏览器交易链接。
 */

import inquirer from "inquirer";
import {
  createWalletClient,
  http,
  parseEther,
  formatEther,
  createPublicClient,
  PublicClient,
  WalletClient,
  parseGwei,
  type TransactionReceipt,
} from "viem";
import { privateKeyToAccount, generatePrivateKey } from "viem/accounts";
import { prepareTransactionRequest } from "viem/actions";
import { foundry, sepolia } from "viem/chains";

const SEPOLIA_RPC_URL = "https://ethereum-sepolia-rpc.publicnode.com";

async function main() {
  try {
    // 1. 选择：新生成私钥 or 输入已有私钥
    const { action } = await inquirer.prompt([
      {
        type: "list",
        name: "action",
        message: "请选择操作：",
        choices: [
          { name: "生成新私钥", value: "generate" },
          { name: "输入已有私钥", value: "input" },
        ],
      },
    ]);

    let privateKey: `0x${string}`;
    if (action === "generate") {
      privateKey = generatePrivateKey();
      console.log("新生成的私钥:", privateKey);
    } else {
      const { pk } = await inquirer.prompt([
        { type: "input", name: "pk", message: "请输入私钥: " },
      ]);
      privateKey = pk;
    }

    const account = privateKeyToAccount(privateKey);
    console.log("钱包地址:", account.address);

    const publicClient: PublicClient = createPublicClient({
      chain: sepolia,
      transport: http(SEPOLIA_RPC_URL),
    });

    const walletClient: WalletClient = createWalletClient({
      account,
      chain: sepolia,
      transport: http(SEPOLIA_RPC_URL),
    });

    // 2. 查询ETH余额
    const balance = await publicClient.getBalance({ address: account.address });
    console.log("ETH余额:", formatEther(balance), "ETH");

    // 3. 现在提醒用户向当前钱包转入ETH，并等待用户确认是否已转账完成或用户确认不需要转账，确认后再次查询ETH余额，确保转入成功。
    console.log("\n请使用其他钱包向本钱包地址转入ETH:");
    console.log("钱包地址:", account.address);
    console.log("等待您完成转账...");

    const { confirmEthTransfer } = await inquirer.prompt([
      {
        type: "confirm",
        name: "confirmEthTransfer",
        message: "请确认您已完成ETH转账（或无需转账），按回车继续查询余额。",
      },
    ]);

    // 再次查询ETH余额
    const newBalance = await publicClient.getBalance({
      address: account.address,
    });
    console.log("当前钱包最新ETH余额:", formatEther(newBalance), "ETH");

    // 4. 手动构建一个交易，并签名发送

    // 请用户输入目标地址和转账金额
    console.log("现在进入手动构建交易并签名发送的环节。");
    const { to } = await inquirer.prompt([
      { type: "input", name: "to", message: "请输入ETH接收方地址:" },
    ]);
    const { amount } = await inquirer.prompt([
      { type: "input", name: "amount", message: "请输入转账金额（ETH）:" },
    ]);

    // 查询区块号
    const blockNumber = await publicClient.getBlockNumber();
    console.log("当前区块号:", blockNumber);

    // 获取当前 gas 价格
    const gasPrice = await publicClient.getGasPrice();
    console.log("当前 gas 价格:", parseGwei(gasPrice.toString()));

    // 查询nonce
    const nonce = await publicClient.getTransactionCount({
      address: account.address,
    });
    console.log("当前 Nonce:", nonce);

    // 构建交易参数
    const txParams = {
      account: account,
      to: to as `0x${string}`,
      value: parseEther(amount),
      chainId: sepolia.id,
      type: "eip1559" as const,
      chain: sepolia,
      nonce: nonce,
    };

    // 自动 Gas 估算及参数验证和补充
    const preparedTx = await prepareTransactionRequest(publicClient, txParams);
    console.log("准备后的交易参数:", {
      ...preparedTx,
      maxFeePerGas: parseGwei(preparedTx.maxFeePerGas.toString()),
      maxPriorityFeePerGas: parseGwei(
        preparedTx.maxPriorityFeePerGas.toString()
      ),
    });

    // 签名交易
    const signedTx = await walletClient.signTransaction(preparedTx);
    console.log("Signed Transaction:", signedTx);

    // 发送交易
    const txHash = await publicClient.sendRawTransaction({
      serializedTransaction: signedTx,
    });
    console.log("Transaction Hash:", txHash);

    // 等待交易确认
    const receipt: TransactionReceipt =
      await publicClient.waitForTransactionReceipt({ hash: txHash });
    console.log("交易状态:", receipt.status === "success" ? "成功" : "失败");
    console.log("区块号:", receipt.blockNumber);
    console.log("Gas 使用量:", receipt.gasUsed.toString());
  } catch (error) {
    console.error("错误:", error);
    if (error instanceof Error) {
      console.error("错误信息:", error.message);
    }
    if (error && typeof error === "object" && "details" in error) {
      console.error("错误详情:", error.details);
    }
    throw error;
  }
}

main();
