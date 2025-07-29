"use client";

/*
## 题目#1 使用 Viem 索引链上 ERC20 转账数据并展示

后端索引出之前自己发行的 ERC20 Token 转账, 并记录到数据库中，并提供一个 Restful 接口来获取某一个地址的转账记录。

前端在用户登录后， 从后端查询出该用户地址的转账记录， 并展示。

要求：模拟两笔以上的转账记录，请贴出 github 和 前端截图。

相关合约代码：foundry_projects/src/W2D4/MyToken.sol
*/

import ERC20_ABI from "./MyToken.json" with { type: "json" };
import { useState, useEffect } from "react";
import { useAppKit } from "@reown/appkit/react";
import { createPublicClient, http, parseEther, formatEther } from "viem";
import { sepolia } from "viem/chains";
import {
  useReadContract,
  useWriteContract,
  useDisconnect,
  useWaitForTransactionReceipt,
  useAccount,
} from "wagmi";

const erc20TokenContractConfig = {
  address: "0xC044905455DBe3ba560FF064304161b9995B1898" as `0x${string}`,
  abi: ERC20_ABI,
  chain: sepolia,
  transport: http("https://1rpc.io/sepolia"),
};

// 转账记录接口类型定义
interface TransferRecord {
  from: string;
  to: string;
  amount: string;
  timestamp: number;
  txHash: string;
}

export default function Home() {
  const { address } = useAccount();

  const { data: erc20Balance, refetch: refetchErc20Balance } = useReadContract({
    ...erc20TokenContractConfig,
    chainId: sepolia.id,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  return (
    <div className="min-h-screen bg-black flex flex-col items-center py-12">
      <h1 className="text-4xl font-extrabold text-center mb-10 bg-gradient-to-r from-blue-400 to-purple-400 text-transparent bg-clip-text drop-shadow-lg">
        ERC20 Token Demo
      </h1>

      <ConnectWallet />

      {/* 当前用户余额显示 */}
      {address && (
        <div className="w-full max-w-4xl mb-6">
          <div className="bg-gray-900 rounded-xl p-4 border border-gray-700">
            <h2 className="text-xl font-bold text-white mb-2">当前账户余额</h2>
            <div className="text-2xl font-mono text-green-400">
              {erc20Balance
                ? `${formatEther(erc20Balance as bigint)} MTK`
                : "加载中..."}
            </div>
          </div>
        </div>
      )}

      {/* 功能区域 */}
      <div className="w-full max-w-4xl space-y-6">
        {/* 转账记录管理 */}
        <TransferRecordsQuery />

        {/* 转账功能和余额查询 - 左右并排 */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* 转账功能 */}
          {address && (
            <TransferToken refetchErc20Balance={refetchErc20Balance} />
          )}

          {/* 余额查询 */}
          <BalanceQuery />
        </div>
      </div>
    </div>
  );
}

// 转账组件
function TransferToken({
  refetchErc20Balance,
}: {
  refetchErc20Balance: () => void;
}) {
  const [modalOpen, setModalOpen] = useState(false);
  const [modalStatus, setModalStatus] = useState<
    "pending" | "success" | "error" | null
  >(null);

  const { address, chain } = useAccount();
  const { data, error, isPending, isError, writeContract } = useWriteContract();
  const { data: receipt, isSuccess } = useWaitForTransactionReceipt({
    hash: data,
  });
  const [amount, setAmount] = useState<string>("");
  const [to, setTo] = useState<string>("");

  useEffect(() => {
    if (isPending) {
      setModalOpen(true);
      setModalStatus("pending");
    } else if (isSuccess) {
      setModalOpen(true);
      setModalStatus("success");
      setAmount("");
      setTo("");
      refetchErc20Balance && refetchErc20Balance();
    } else if (isError) {
      setModalOpen(true);
      setModalStatus("error");
    }
  }, [isPending, isSuccess, isError, refetchErc20Balance]);

  const handleTransfer = (amount: string, to: string) => {
    if (!address) {
      alert("请先连接钱包！");
      return;
    }
    if (!to || !amount) {
      alert("请填写Token数量和接收地址！");
      return;
    }
    writeContract({
      ...erc20TokenContractConfig,
      functionName: "transfer",
      args: [to, parseEther(amount)],
    });
  };

  return (
    <div className="bg-gray-900 rounded-xl p-6 border border-gray-700">
      <h2 className="text-2xl font-bold text-white mb-4">转账</h2>
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">
            接收地址
          </label>
          <input
            type="text"
            value={to}
            onChange={(e) => setTo(e.target.value)}
            placeholder="0x..."
            className="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-green-500 focus:ring-1 focus:ring-green-500"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">
            转账数量 (MTK)
          </label>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.0"
            step="0.000001"
            className="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-green-500 focus:ring-1 focus:ring-green-500"
          />
        </div>
        <button
          onClick={() => handleTransfer(amount, to)}
          disabled={isPending || !amount || !to}
          className="w-full bg-gradient-to-r from-green-500 to-green-600 hover:from-green-400 hover:to-green-500 disabled:opacity-50 disabled:cursor-not-allowed text-white px-6 py-3 rounded-lg font-semibold transition duration-200 shadow-lg"
        >
          {isPending ? "转账中..." : "确认转账"}
        </button>
      </div>
      <TxModal
        open={modalOpen}
        onClose={() => {
          setModalOpen(false);
          setModalStatus(null);
        }}
        status={modalStatus}
        hash={data}
        receipt={receipt}
        error={error}
        chain={chain}
        amount={amount}
      />
    </div>
  );
}

// 余额查询组件
function BalanceQuery() {
  const [queryAddress, setQueryAddress] = useState<string>("");
  const [queryBalance, setQueryBalance] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const handleQuery = async (queryAddress: string) => {
    if (!queryAddress) {
      alert("请填写查询地址！");
      return;
    }

    setIsLoading(true);
    try {
      const publicClient = createPublicClient({
        chain: sepolia,
        transport: http("https://1rpc.io/sepolia"),
      });

      const balance = await publicClient.readContract({
        address: erc20TokenContractConfig.address,
        abi: erc20TokenContractConfig.abi,
        functionName: "balanceOf",
        args: [queryAddress as `0x${string}`],
      });

      setQueryBalance(formatEther(balance as bigint));
    } catch (error) {
      console.error("查询余额失败:", error);
      alert("查询余额失败，请检查地址格式");
      setQueryBalance(null);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="bg-gray-900 rounded-xl p-6 border border-gray-700">
      <h2 className="text-2xl font-bold text-white mb-4">查询用户余额</h2>
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">
            用户地址
          </label>
          <input
            type="text"
            value={queryAddress}
            onChange={(e) => setQueryAddress(e.target.value)}
            placeholder="0x..."
            className="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-green-500 focus:ring-1 focus:ring-green-500"
          />
        </div>
        <button
          onClick={() => handleQuery(queryAddress)}
          disabled={!queryAddress || isLoading}
          className="w-full bg-gradient-to-r from-green-500 to-green-600 hover:from-green-400 hover:to-green-500 disabled:opacity-50 disabled:cursor-not-allowed text-white px-6 py-3 rounded-lg font-semibold transition duration-200 shadow-lg"
        >
          {isLoading ? "查询中..." : "查询余额"}
        </button>
        {queryBalance && (
          <div className="mt-4 p-4 bg-gray-800 rounded-lg border border-gray-600">
            <div className="text-lg font-mono text-green-400">
              余额: {queryBalance} MTK
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

// 转账记录查询组件
function TransferRecordsQuery() {
  const [transferRecords, setTransferRecords] = useState<TransferRecord[]>([]);
  const [recordQueryAddress, setRecordQueryAddress] = useState("");
  const [isLoadingRecords, setIsLoadingRecords] = useState(false);
  const [isScanning, setIsScanning] = useState(false);

  // 扫描参数
  const [scanParams, setScanParams] = useState({
    tokenAddress: "0xC044905455DBe3ba560FF064304161b9995B1898",
    fromBlock: "",
    toBlock: "",
    fromAddress: "",
    toAddress: "",
  });

  const handleQueryTransferRecords = async () => {
    if (!recordQueryAddress) {
      alert("请输入要查询的地址");
      return;
    }

    setIsLoadingRecords(true);
    try {
      const response = await fetch(
        `/api/transfer-records?address=${recordQueryAddress}&page=1&limit=50`
      );

      if (response.ok) {
        const result = await response.json();
        if (result.success) {
          // 转换数据格式
          const records: TransferRecord[] = result.data.map((item: any) => ({
            from: item.from_address,
            to: item.to_address,
            amount: (BigInt(item.amount) / BigInt(10 ** 18)).toString(),
            timestamp: item.timestamp * 1000, // 转换为毫秒
            txHash: item.transaction_hash,
          }));
          setTransferRecords(records);
        } else {
          alert(result.error || "查询失败");
          setTransferRecords([]);
        }
      } else {
        const errorData = await response.json();
        alert(errorData.error || "查询失败");
        setTransferRecords([]);
      }
    } catch (error) {
      console.error("查询转账记录失败:", error);
      alert("网络错误，请稍后重试");
      setTransferRecords([]);
    } finally {
      setIsLoadingRecords(false);
    }
  };

  const handleScanBlockchain = async () => {
    setIsScanning(true);
    try {
      const response = await fetch("/api/scan", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          tokenAddress: scanParams.tokenAddress,
          fromBlock: scanParams.fromBlock || undefined,
          toBlock: scanParams.toBlock || undefined,
          fromAddress: scanParams.fromAddress || undefined,
          toAddress: scanParams.toAddress || undefined,
        }),
      });

      if (response.ok) {
        const result = await response.json();
        if (result.success) {
          alert(
            `扫描完成！找到 ${result.data.totalLogs} 条记录，插入 ${result.data.insertedRecords} 条新记录`
          );
          // 扫描完成后自动刷新显示
          if (recordQueryAddress) {
            await handleQueryTransferRecords();
          }
        } else {
          alert(result.error || "扫描失败");
        }
      } else {
        const errorData = await response.json();
        alert(errorData.error || "扫描失败");
      }
    } catch (error) {
      console.error("扫描区块链失败:", error);
      alert("网络错误，请稍后重试");
    } finally {
      setIsScanning(false);
    }
  };

  return (
    <div className="bg-gray-900 rounded-xl p-6 border border-gray-700">
      <h2 className="text-2xl font-bold text-white mb-4">转账记录管理</h2>

      {/* 扫描区块链区域 */}
      <div className="mb-6 p-4 bg-gray-800 rounded-lg border border-gray-600">
        <h3 className="text-lg font-semibold text-white mb-3">扫描区块链</h3>

        {/* 说明区域 */}
        <div className="mb-4 p-3 bg-yellow-900/20 border border-yellow-600/30 rounded-lg">
          <div className="flex items-start gap-2">
            <div className="text-yellow-200 text-sm">
              <strong>注意：</strong>RPC 提供商限制单次查询最多 10,000 个区块。
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-4">
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1">
              代币合约地址
            </label>
            <input
              type="text"
              value={scanParams.tokenAddress}
              onChange={(e) =>
                setScanParams({ ...scanParams, tokenAddress: e.target.value })
              }
              placeholder="0x..."
              className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-green-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1">
              起始区块 (可选)
            </label>
            <input
              type="number"
              value={scanParams.fromBlock}
              onChange={(e) =>
                setScanParams({ ...scanParams, fromBlock: e.target.value })
              }
              placeholder="留空使用默认值"
              className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-green-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1">
              结束区块 (可选)
            </label>
            <input
              type="number"
              value={scanParams.toBlock}
              onChange={(e) =>
                setScanParams({ ...scanParams, toBlock: e.target.value })
              }
              placeholder="留空使用默认值"
              className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-green-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1">
              发送方地址 (可选)
            </label>
            <input
              type="text"
              value={scanParams.fromAddress}
              onChange={(e) =>
                setScanParams({ ...scanParams, fromAddress: e.target.value })
              }
              placeholder="0x..."
              className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-green-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1">
              接收方地址 (可选)
            </label>
            <input
              type="text"
              value={scanParams.toAddress}
              onChange={(e) =>
                setScanParams({ ...scanParams, toAddress: e.target.value })
              }
              placeholder="0x..."
              className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-green-500"
            />
          </div>
        </div>
        <button
          onClick={handleScanBlockchain}
          disabled={isScanning}
          className="w-full bg-gradient-to-r from-blue-500 to-blue-600 hover:from-blue-400 hover:to-blue-500 disabled:opacity-50 disabled:cursor-not-allowed text-white px-6 py-3 rounded-lg font-semibold transition duration-200 shadow-lg"
        >
          {isScanning ? "扫描中..." : "扫描区块链"}
        </button>
      </div>

      {/* 查询记录区域 */}
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">
            查询地址
          </label>
          <div className="flex gap-2">
            <input
              type="text"
              value={recordQueryAddress}
              onChange={(e) => setRecordQueryAddress(e.target.value)}
              placeholder="0x..."
              className="flex-1 px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-green-500 focus:ring-1 focus:ring-green-500"
            />
            <button
              onClick={handleQueryTransferRecords}
              disabled={!recordQueryAddress || isLoadingRecords}
              className="bg-gradient-to-r from-green-500 to-green-600 hover:from-green-400 hover:to-green-500 disabled:opacity-50 disabled:cursor-not-allowed text-white px-6 py-3 rounded-lg font-semibold transition duration-200 shadow-lg"
            >
              {isLoadingRecords ? "查询中..." : "查询记录"}
            </button>
          </div>
        </div>

        {/* 转账记录显示 */}
        {transferRecords.length > 0 && (
          <div className="mt-6">
            <h3 className="text-lg font-semibold text-white mb-3">
              转账记录 ({transferRecords.length} 条)
            </h3>
            <div className="space-y-3 max-h-96 overflow-y-auto">
              {transferRecords.map((record, index) => (
                <TransferRecordItem key={index} record={record} />
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

// 转账记录项组件
function TransferRecordItem({ record }: { record: TransferRecord }) {
  return (
    <div className="bg-gray-800 rounded-lg p-4 border border-gray-600">
      <div className="grid grid-cols-1 gap-2 text-sm">
        <div className="flex justify-between">
          <span className="text-gray-400">发送方:</span>
          <span className="text-white font-mono">{record.from}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-400">接收方:</span>
          <span className="text-white font-mono">{record.to}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-400">数量:</span>
          <span className="text-green-400 font-mono">{record.amount} MTK</span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-400">时间:</span>
          <span className="text-white">
            {new Date(record.timestamp).toLocaleString()}
          </span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-400">交易哈希:</span>
          <span className="text-blue-400 font-mono text-xs truncate">
            {record.txHash}
          </span>
        </div>
      </div>
    </div>
  );
}

// 钱包连接组件
function ConnectWallet() {
  const { open } = useAppKit();
  const { address, isConnected } = useAccount();
  const { disconnect } = useDisconnect();

  return (
    <div className="fixed top-4 right-8 z-30 flex items-center gap-3">
      {isConnected ? (
        <>
          <span className="bg-gray-800 text-white px-3 py-2 rounded-lg shadow text-sm font-mono border border-gray-600">
            {address ? `${address.slice(0, 6)}...${address.slice(-4)}` : ""}
          </span>
          <button
            onClick={() => disconnect()}
            className="bg-gradient-to-r from-red-500 to-red-600 hover:from-red-400 hover:to-red-500 text-white px-4 py-2 rounded-lg shadow font-semibold transition duration-200"
          >
            断开连接
          </button>
        </>
      ) : (
        <button
          onClick={() => open()}
          className="bg-gradient-to-r from-green-500 to-green-600 hover:from-green-400 hover:to-green-500 text-white px-6 py-2 rounded-lg shadow font-semibold transition duration-200"
        >
          连接钱包
        </button>
      )}
    </div>
  );
}

// 交易模态框组件
type TxModalProps = {
  open: boolean;
  onClose: () => void;
  status: "pending" | "success" | "error" | null;
  hash?: string;
  receipt?: any;
  error?: any;
  chain?: any;
  amount?: string;
};

function TxModal(props: TxModalProps) {
  if (!props.open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-60">
      <div className="bg-gray-900 rounded-2xl shadow-lg p-8 min-w-[320px] max-w-lg text-white relative border border-gray-700">
        <button
          className="absolute top-2 right-4 text-gray-400 hover:text-white text-2xl font-bold"
          onClick={props.onClose}
        >
          ×
        </button>

        {props.status === "pending" && (
          <div className="text-center">
            <div className="text-lg font-semibold text-green-400 mb-2">
              正在发送交易
            </div>
            <div className="text-gray-300 mb-4">请稍等，交易正在处理中...</div>
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-green-400 mx-auto"></div>
          </div>
        )}

        {props.status === "success" && (
          <>
            <div className="text-center mb-4">
              <div className="text-lg font-bold text-green-400 mb-2">
                交易成功！
              </div>
              {props.amount && (
                <div className="text-gray-300">
                  转账数量: {props.amount} MTK
                </div>
              )}
            </div>

            {props.hash && props.chain && (
              <div className="mb-4 p-3 bg-gray-800 rounded-lg border border-gray-600">
                <div className="text-sm text-gray-300 mb-2">交易哈希:</div>
                <a
                  target="_blank"
                  rel="noopener noreferrer"
                  href={`${props.chain?.blockExplorers?.default?.url}/tx/${props.hash}`}
                  className="text-blue-400 hover:text-blue-300 break-all underline text-sm"
                >
                  {props.hash}
                </a>
              </div>
            )}

            {props.receipt && (
              <div className="mt-4 max-h-40 overflow-auto bg-gray-800 rounded p-3 text-xs border border-gray-600">
                <div className="text-gray-300 mb-2">交易回执:</div>
                <pre className="text-gray-400">
                  {JSON.stringify(props.receipt, null, 2)}
                </pre>
              </div>
            )}

            <div className="mt-6 flex justify-center">
              <button
                onClick={props.onClose}
                className="bg-green-600 hover:bg-green-500 text-white px-6 py-2 rounded-lg font-semibold transition duration-200"
              >
                确认
              </button>
            </div>
          </>
        )}

        {props.status === "error" && (
          <div className="text-center">
            <div className="text-red-400 font-bold text-lg mb-2">交易失败</div>
            <div className="text-gray-300 mb-4">
              {props.error?.message || "未知错误"}
            </div>

            <button
              onClick={props.onClose}
              className="bg-red-600 hover:bg-red-500 text-white px-6 py-2 rounded-lg font-semibold transition duration-200"
            >
              确认
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
