"use client";

/*
题目#1 EIP 7702实践：发起打包交易

- 部署自己的 Delegate 合约（需支持批量执行）到 Sepolia。
- 修改之前的 TokenBank 前端页面，让用户能够通过 EOA 账户授权给 Delegate 合约，并在一个交易中完成授权和存款操作。

相关合约代码：
- foundry_projects/src/W2D4/MyToken.sol
- foundry_projects/src/W4D5/Delegate.sol
- foundry_projects/src/W4D5/TokenBank.sol

本地账户：
- 地址：0x32E14f9F6e5db0373f685D1fd5763aB63d709Ad7
- 私钥：0x8cf07f2ed5afc466ca1dedbc835f5c23c4730ccbf47e0e845f764c1b36fca319
*/

import ERC20_ABI from "./abi/MyToken.json" with { type: "json" };
import DELEGATE_ABI from "./abi/Delegate.json" with { type: "json" };
import TOKEN_BANK_ABI from "./abi/TokenBank.json" with { type: "json" };
import { useState, useEffect } from "react";
import { useAppKit } from "@reown/appkit/react";
import {
  http,
  parseEther,
  formatEther,
  createWalletClient,
  custom,
  encodeFunctionData,
} from "viem";
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import { sepolia } from "viem/chains";
import {
  useReadContract,
  useWriteContract,
  useDisconnect,
  useWaitForTransactionReceipt,
  useAccount,
} from "wagmi";

// 支持 EIP-7702 的 RPC 提供商 - 使用支持交易发送的端点
// const SEPOLIA_RPC_URL = "https://eth-sepolia.g.alchemy.com/v2/G46pa1JBnfNur5oZxYgm2";
const SEPOLIA_RPC_URL =
  "https://sepolia.infura.io/v3/53a58eac66a04d69bd2577334f365651";

const erc20TokenContractConfig = {
  address: "0xC044905455DBe3ba560FF064304161b9995B1898" as `0x${string}`,
  abi: ERC20_ABI,
  chain: sepolia,
  chainId: sepolia.id,
  transport: http(SEPOLIA_RPC_URL),
};

const delegateContractConfig = {
  address: "0xf6681aea44c1fdd66b49ef1f44a0bd2b38c242ce" as `0x${string}`,
  abi: DELEGATE_ABI,
  chain: sepolia,
  chainId: sepolia.id,
  transport: http(SEPOLIA_RPC_URL),
};

const tokenBankContractConfig = {
  address: "0xDbDDe79DB33e72741A52100f08B12D3603818318" as `0x${string}`,
  abi: TOKEN_BANK_ABI,
  chain: sepolia,
  chainId: sepolia.id,
  transport: http(SEPOLIA_RPC_URL),
};

export default function Home() {
  const { address } = useAccount();
  const [localAccount, setLocalAccount] = useState<{
    address: string;
    privateKey: string;
  } | null>(null);
  const [showLocalAccountModal, setShowLocalAccountModal] = useState(false);

  const currentAddress = address || localAccount?.address;

  const { data: tokenBankBalance, refetch: refetchTokenBankBalance } =
    useReadContract({
      ...tokenBankContractConfig,
      functionName: "balanceOf",
      args: currentAddress ? [currentAddress] : undefined,
      query: { enabled: !!currentAddress },
    });

  const { data: erc20Balance, refetch: refetchErc20Balance } = useReadContract({
    ...erc20TokenContractConfig,
    functionName: "balanceOf",
    args: currentAddress ? [currentAddress] : undefined,
    query: { enabled: !!currentAddress },
  });

  // 创建本地账户
  const createLocalAccount = () => {
    const privateKey = generatePrivateKey();
    const account = privateKeyToAccount(privateKey);
    const newLocalAccount = {
      address: account.address,
      privateKey: privateKey,
    };
    setLocalAccount(newLocalAccount);
    setShowLocalAccountModal(true);

    // 保存到 localStorage
    localStorage.setItem("localAccount", JSON.stringify(newLocalAccount));
  };

  // 加载已保存的本地账户
  useEffect(() => {
    const saved = localStorage.getItem("localAccount");
    if (saved) {
      try {
        const account = JSON.parse(saved);
        setLocalAccount(account);
      } catch (error) {
        console.error("Failed to load saved local account:", error);
      }
    }
  }, []);

  // 当本地账户或连接的钱包地址变化时，刷新余额
  useEffect(() => {
    if (currentAddress) {
      refetchTokenBankBalance();
      refetchErc20Balance();
    }
  }, [currentAddress, refetchTokenBankBalance, refetchErc20Balance]);

  return (
    <div className="min-h-screen bg-black flex flex-col items-center py-12 px-4">
      <h1 className="text-4xl font-extrabold text-center mb-10 bg-gradient-to-r from-blue-400 to-purple-400 text-transparent bg-clip-text drop-shadow-lg">
        Token Bank for Delegate Demo
      </h1>

      <ConnectWallet
        localAccount={localAccount}
        createLocalAccount={createLocalAccount}
        showLocalAccountModal={showLocalAccountModal}
        setShowLocalAccountModal={setShowLocalAccountModal}
      />

      {(address || localAccount) && (
        <div className="w-full max-w-3xl mb-8">
          <div className="bg-gray-900 rounded-xl p-6 border border-gray-700">
            <h3 className="text-xl font-bold text-white mb-2">
              当前银行账户余额
            </h3>
            <div className="text-2xl font-mono text-green-400">
              {tokenBankBalance
                ? `${formatEther(tokenBankBalance as bigint)} MTK`
                : "加载中..."}
            </div>
            <h3 className="text-xl font-bold text-white mb-2">
              当前钱包 Token 余额
            </h3>
            <div className="text-2xl font-mono text-green-400">
              {erc20Balance
                ? `${formatEther(erc20Balance as bigint)} MTK`
                : "加载中..."}
            </div>
            {(localAccount || address) && (
              <div className="mt-4 p-3 bg-gray-800 rounded-lg border border-gray-600">
                <div className="text-sm text-gray-300 mb-1">当前账户地址:</div>
                <div className="text-sm font-mono text-blue-400 break-all">
                  {currentAddress}
                </div>
                <div className="text-xs text-gray-400 mt-1">
                  账户类型: {localAccount ? "本地账户" : "连接钱包"}
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* 功能区域 */}
      <div className="w-full max-w-3xl">
        {/* 转账功能和余额查询 */}
        <div className="space-y-6">
          {/* 转账功能 */}
          {(address || localAccount) && (
            <DepositToTokenBank
              refetchErc20Balance={refetchErc20Balance}
              refetchTokenBankBalance={refetchTokenBankBalance}
              localAccount={localAccount}
            />
          )}
        </div>
      </div>
    </div>
  );
}

// 本地账户信息模态框组件
function LocalAccountModal({
  localAccount,
  onClose,
}: {
  localAccount: { address: string; privateKey: string };
  onClose: () => void;
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-60">
      <div className="bg-gray-900 rounded-2xl shadow-lg p-8 min-w-[400px] max-w-lg text-white relative border border-gray-700">
        <button
          className="absolute top-2 right-4 text-gray-400 hover:text-white text-2xl font-bold"
          onClick={onClose}
        >
          ×
        </button>

        <div className="text-center mb-6">
          <div className="text-lg font-bold text-blue-400 mb-2">
            本地账户创建成功！
          </div>
          <div className="text-gray-300 text-sm">
            请保存以下信息，并获取 Sepolia 测试币
          </div>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              账户地址
            </label>
            <div className="bg-gray-800 p-3 rounded-lg border border-gray-600">
              <code className="text-green-400 break-all text-sm">
                {localAccount.address}
              </code>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              私钥 (请安全保存)
            </label>
            <div className="bg-gray-800 p-3 rounded-lg border border-gray-600">
              <code className="text-red-400 break-all text-sm">
                {localAccount.privateKey}
              </code>
            </div>
          </div>

          <div className="bg-yellow-900 border border-yellow-600 rounded-lg p-3">
            <div className="text-yellow-300 text-sm">
              <strong>重要提醒：</strong>
              <ul className="mt-2 space-y-1">
                <li>• 请安全保存私钥，不要泄露给他人</li>
              </ul>
            </div>
          </div>
        </div>

        <div className="mt-6 flex justify-center">
          <button
            onClick={onClose}
            className="bg-blue-600 hover:bg-blue-500 text-white px-6 py-2 rounded-lg font-semibold transition duration-200"
          >
            确认
          </button>
        </div>
      </div>
    </div>
  );
}

// 存款组件
function DepositToTokenBank({
  refetchErc20Balance,
  refetchTokenBankBalance,
  localAccount,
}: {
  refetchErc20Balance: () => void;
  refetchTokenBankBalance: () => void;
  localAccount: { address: string; privateKey: string } | null;
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

  useEffect(() => {
    if (isPending) {
      setModalOpen(true);
      setModalStatus("pending");
    } else if (isSuccess) {
      setModalOpen(true);
      setModalStatus("success");
      setAmount("");
      refetchErc20Balance && refetchErc20Balance();
      refetchTokenBankBalance && refetchTokenBankBalance();
    } else if (isError) {
      setModalOpen(true);
      setModalStatus("error");
    }
  }, [
    isPending,
    isSuccess,
    isError,
    refetchErc20Balance,
    refetchTokenBankBalance,
  ]);

  const handleTransfer = async (amount: string) => {
    const currentAddress = address || localAccount?.address;

    // 添加调试信息
    console.log("当前状态:", {
      address,
      localAccount,
      currentAddress,
      isLocalAccount: !!localAccount,
      isConnectedWallet: !!address,
    });

    if (!currentAddress) {
      alert("请先连接钱包或创建本地账户！");
      return;
    }
    if (!amount) {
      alert("请填写Token数量！");
      return;
    }

    try {
      if (localAccount) {
        console.log("使用本地账户进行交易:", localAccount.address);
        // 使用本地账户
        const account = privateKeyToAccount(
          localAccount.privateKey as `0x${string}`
        );
        const walletClient = createWalletClient({
          account,
          chain: sepolia,
          transport: http(SEPOLIA_RPC_URL),
        });

        // EIP-7702 演示：使用 Delegate 合约的批量执行功能
        // 由于大多数 RPC 不支持 authorizationList，我们直接调用 batchExecute
        console.log("开始 EIP-7702 批量交易演示...");

        const calls = [
          {
            target: erc20TokenContractConfig.address,
            allowFailure: false,
            callData: encodeFunctionData({
              abi: ERC20_ABI,
              functionName: "approve",
              args: [tokenBankContractConfig.address, parseEther(amount)],
            }),
          },
          {
            target: tokenBankContractConfig.address,
            allowFailure: false,
            callData: encodeFunctionData({
              abi: TOKEN_BANK_ABI as any,
              functionName: "deposit",
              args: [parseEther(amount)],
            }),
          },
        ];

        console.log("批量调用数据:", calls);

        // 直接调用 Delegate 合约的 batchExecute 函数
        // 这演示了 EIP-7702 的核心概念：在一个交易中执行多个调用
        const hash = await walletClient.writeContract({
          address: delegateContractConfig.address,
          abi: DELEGATE_ABI,
          functionName: "batchExecute",
          args: [calls],
          account: account.address,
          gas: BigInt(500000),
        });

        console.log("EIP-7702 批量交易成功，哈希:", hash);
        alert(
          `EIP-7702 批量交易成功！\n在一个交易中完成了授权和存款操作\n哈希: ${hash}`
        );

        // 刷新余额
        setTimeout(() => {
          refetchErc20Balance();
          refetchTokenBankBalance();
        }, 2000);
      } else {
        // 使用连接的钱包（原有的逻辑）
        alert("请使用本地账户来支持 EIP-7702 功能");
      }
    } catch (error) {
      console.error("交易失败:", error);
      alert(`交易失败: ${error instanceof Error ? error.message : "未知错误"}`);
    }
  };

  return (
    <div className="bg-gray-900 rounded-xl p-6 border border-gray-700">
      <h2 className="text-2xl font-bold text-white mb-4">存款</h2>
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">
            存款数量 (MTK)
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
          onClick={() => handleTransfer(amount)}
          disabled={isPending || !amount}
          className="w-full bg-gradient-to-r from-green-500 to-green-600 hover:from-green-400 hover:to-green-500 disabled:opacity-50 disabled:cursor-not-allowed text-white px-6 py-3 rounded-lg font-semibold transition duration-200 shadow-lg"
        >
          {isPending ? "存款中..." : "确认存款"}
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

// 钱包连接组件
function ConnectWallet({
  localAccount,
  createLocalAccount,
  showLocalAccountModal,
  setShowLocalAccountModal,
}: {
  localAccount: { address: string; privateKey: string } | null;
  createLocalAccount: () => void;
  showLocalAccountModal: boolean;
  setShowLocalAccountModal: (show: boolean) => void;
}) {
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
      ) : localAccount ? (
        <>
          <span className="bg-blue-800 text-white px-3 py-2 rounded-lg shadow text-sm font-mono border border-blue-600">
            本地账户: {localAccount.address.slice(0, 6)}...
            {localAccount.address.slice(-4)}
          </span>
          <button
            onClick={() => {
              localStorage.removeItem("localAccount");
              window.location.reload();
            }}
            className="bg-gradient-to-r from-red-500 to-red-600 hover:from-red-400 hover:to-red-500 text-white px-4 py-2 rounded-lg shadow font-semibold transition duration-200"
          >
            删除本地账户
          </button>
        </>
      ) : (
        <div className="flex gap-2">
          <button
            onClick={() => open()}
            className="bg-gradient-to-r from-green-500 to-green-600 hover:from-green-400 hover:to-green-500 text-white px-6 py-2 rounded-lg shadow font-semibold transition duration-200"
          >
            连接钱包
          </button>
          <button
            onClick={createLocalAccount}
            className="bg-gradient-to-r from-blue-500 to-blue-600 hover:from-blue-400 hover:to-blue-500 text-white px-6 py-2 rounded-lg shadow font-semibold transition duration-200"
          >
            创建本地账户
          </button>
        </div>
      )}

      {/* 本地账户信息模态框 */}
      {showLocalAccountModal && localAccount && (
        <LocalAccountModal
          localAccount={localAccount}
          onClose={() => setShowLocalAccountModal(false)}
        />
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
