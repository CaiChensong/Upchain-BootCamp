"use client";

/*
题目#1

使用 Viem 为 TokenBank 搭建一个简单的前端：

- 显示当前 Token 的余额，并且可以存款(点击按钮存款)到 TokenBank
- 存款后显示用户存款金额，同时支持用户取款(点击按钮取款)。

提交的 github 仓库需要包含一个存款后的截图。

相关合约：
- foundry_projects/src/W3D1/ERC20.sol
- foundry_projects/src/W3D1/TokenBank.sol
*/

import {
  createPublicClient,
  createWalletClient,
  getContract,
  http,
  publicActions,
  walletActions,
} from "viem";
import { foundry } from "viem/chains";

import ERC20_ABI from "./abi/ERC20Extend.json" with { type: "json" };
import TOKEN_BANK_ABI from "./abi/TokenBankV2.json" with { type: "json" };
import { privateKeyToAccount } from "viem/accounts";
import { useState, useEffect } from "react";

export default function Home() {
  const RPC_URL = "http://127.0.0.1:8545";
  const PRIVATE_KEY =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

  const TOKEN_BANK_ADDRESS = "0xe7f1725e7734ce288f8367e1bb143e90bb3f0512";
  const ERC20_TOKEN_ADDRESS = "0x5fbdb2315678afecb367f032d93f642f64180aa3";

  const [amount, setAmount] = useState("");
  const [bankBalance, setBankBalance] = useState<string>("0");
  const [userBalance, setUserBalance] = useState<string>("0");

  // publicClient
  const publicClient = createPublicClient({
    chain: foundry,
    transport: http(RPC_URL),
  }).extend(publicActions);

  // walletClient
  const account = privateKeyToAccount(PRIVATE_KEY);
  const walletClient = createWalletClient({
    account,
    chain: foundry,
    transport: http(RPC_URL),
  }).extend(publicActions);

  // 查询 bank 的 token 余额
  const fetchBankBalance = async () => {
    const balance = await publicClient.readContract({
      address: ERC20_TOKEN_ADDRESS,
      abi: ERC20_ABI,
      functionName: "balanceOf",
      args: [TOKEN_BANK_ADDRESS],
    });
    setBankBalance((balance as bigint).toString());
  };

  // 查询当前用户在 bank 的存款余额
  const fetchUserBalance = async () => {
    const balance = await publicClient.readContract({
      address: TOKEN_BANK_ADDRESS,
      abi: TOKEN_BANK_ABI,
      functionName: "balances",
      args: [account.address],
    });
    setUserBalance((balance as bigint).toString());
    return (balance as bigint).toString();
  };

  useEffect(() => {
    fetchBankBalance();
    fetchUserBalance();
  }, []);

  const handleDeposit = async () => {
    await walletClient.writeContract({
      address: ERC20_TOKEN_ADDRESS,
      abi: ERC20_ABI,
      functionName: "transferWithCallback",
      args: [TOKEN_BANK_ADDRESS, BigInt(amount)],
    });
    await fetchBankBalance();
    const userBalance = await fetchUserBalance();
    alert(`存款成功！当前账户余额为：${userBalance}`);
    setAmount("");
  };

  const handleWithdraw = async () => {
    await walletClient.writeContract({
      address: TOKEN_BANK_ADDRESS,
      abi: TOKEN_BANK_ABI,
      functionName: "withdraw",
      args: [BigInt(amount)],
    });
    await fetchBankBalance();
    const userBalance = await fetchUserBalance();
    alert(`取款成功！当前账户余额为：${userBalance}`);
    setAmount("");
  };

  return (
    <div className="font-sans grid grid-rows-[20px_1fr_20px] items-center justify-items-center min-h-screen p-8 pb-20 gap-16 sm:p-20">
      <main className="flex flex-col gap-[32px] row-start-2 items-center sm:items-start">
        <h1 className="text-4xl font-extrabold tracking-tight text-center mb-4 bg-gradient-to-r from-blue-500 to-purple-500 text-transparent bg-clip-text drop-shadow-md">
          Aerial Token Bank
        </h1>
        <div className="mb-2 text-lg font-semibold text-gray-700 dark:text-gray-200">
          Bank 总余额：{bankBalance}
        </div>
        <div className="flex gap-4 items-center flex-col sm:flex-row">
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="输入金额"
            className="rounded-full border border-solid border-black/[.08] dark:border-white/[.145] transition-colors px-4 py-2 text-base focus:outline-none focus:ring-2 focus:ring-blue-400 bg-white dark:bg-[#222] text-gray-900 dark:text-gray-100 shadow-sm w-48"
          />
          <button
            onClick={handleDeposit}
            className="rounded-full border border-solid border-transparent transition-colors flex items-center justify-center bg-blue-600 text-white gap-2 hover:bg-blue-700 font-medium text-base h-10 px-6 shadow-md"
          >
            存款
          </button>
          <button
            onClick={handleWithdraw}
            className="rounded-full border border-solid border-blue-600 transition-colors flex items-center justify-center bg-white text-blue-600 gap-2 hover:bg-blue-50 font-medium text-base h-10 px-6 shadow-md"
          >
            取款
          </button>
        </div>
      </main>
    </div>
  );
}
