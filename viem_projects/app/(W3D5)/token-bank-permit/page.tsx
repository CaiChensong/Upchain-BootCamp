"use client";

/*
- 在 TokenBank 前端加入通过签名存款。

- 修改 Token 存款前端 让用户可以在前端通过 permit2 的签名存款。

相关合约：
- foundry_projects/src/W3D5/ERC20PermitToken.sol
- foundry_projects/src/W3D5/TokenBankPermit.sol
*/

import ERC20_PERMIT_TOKEN_ABI from "./abi/ERC20PermitToken.json" with { type: "json" };
import TOKEN_BANK_PERMIT_ABI from "./abi/TokenBankPermit.json" with { type: "json" };
import PERMIT2_ABI from "./abi/Permit2.json" with { type: "json" };
import { useState, useEffect } from "react";
import { useAppKit } from "@reown/appkit/react";
import {
  useAccount,
  useDisconnect,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  useSignTypedData,
} from "wagmi";
import { parseEther, parseSignature } from "viem";
import { stringify } from "viem";

export default function Home() {
  const { address } = useAccount();

  const { data: erc20Balance, refetch: refetchErc20Balance } = useReadContract({
    ...erc20PermitTokenContractConfig,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const { data: bankBalance, refetch: refetchBankBalance } = useReadContract({
    ...tokenBankPermitContractConfig,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
      retry: false, // 不重试失败的调用
    },
  });

  return (
    <div className="min-h-screen bg-black flex flex-col items-center py-12">
      <h1 className="text-4xl font-extrabold text-center mb-10 bg-gradient-to-r from-blue-400 to-purple-400 text-transparent bg-clip-text drop-shadow-lg">
        Token Bank with Permit Demo
      </h1>

      <div className="w-full max-w-4xl mb-8">
        <div className="bg-gray-900 rounded-2xl shadow-lg p-6">
          <div className="bg-gray-800 rounded-xl p-4 mb-4">
            <span className="font-bold text-white text-lg">当前账户余额：</span>
            <span className="text-white text-lg ml-2">
              {bankBalance ? Number(bankBalance) / 1e18 : "--"} Token
            </span>
          </div>
          <div className="bg-gray-800 rounded-xl p-4">
            <span className="font-bold text-white text-lg">
              钱包Token余额：
            </span>
            <span className="text-white text-lg ml-2">
              {erc20Balance ? Number(erc20Balance) / 1e18 : "--"} Token
            </span>
          </div>
        </div>
      </div>

      <div className="w-full max-w-4xl flex flex-col md:flex-row gap-8 mb-8 justify-center">
        <div className="flex-1 flex flex-col gap-4 max-w-md w-full">
          <DepositWithPermit
            refetchErc20Balance={refetchErc20Balance}
            refetchBankBalance={refetchBankBalance}
          />
        </div>
        <div className="flex-1 flex flex-col gap-4 max-w-md w-full">
          <DepositWithPermit2
            refetchErc20Balance={refetchErc20Balance}
            refetchBankBalance={refetchBankBalance}
          />
        </div>
      </div>

      <div className="w-full max-w-4xl flex flex-col md:flex-row gap-8 mb-12 justify-center">
        <div className="flex-1 flex flex-col gap-4 max-w-md w-full">
          <DepositToBank
            refetchErc20Balance={refetchErc20Balance}
            refetchBankBalance={refetchBankBalance}
          />
        </div>
        <div className="flex-1 flex flex-col gap-4 max-w-md w-full">
          <WithdrawFromBank
            refetchErc20Balance={refetchErc20Balance}
            refetchBankBalance={refetchBankBalance}
          />
        </div>
      </div>

      <ConnectWallet />
    </div>
  );
}

const erc20PermitTokenContractConfig = {
  address: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512" as `0x${string}`, // ERC20 Token合约地址
  abi: ERC20_PERMIT_TOKEN_ABI,
};

const tokenBankPermitContractConfig = {
  address: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0" as `0x${string}`, // TokenBank合约地址
  abi: TOKEN_BANK_PERMIT_ABI,
};

const permit2ContractConfig = {
  address: "0x000000000022D473030F116dDEE9F6B43aC78BA3" as `0x${string}`,
  abi: PERMIT2_ABI,
};

function ConnectWallet() {
  const { open } = useAppKit();
  const { address, isConnected } = useAccount();
  const { disconnect } = useDisconnect();

  return (
    <div className="fixed top-4 right-8 z-30 flex items-center gap-3">
      {isConnected ? (
        <>
          <span className="bg-gray-800 text-white px-3 py-1 rounded-lg shadow text-sm font-mono">
            {address ? `${address.slice(0, 6)}...${address.slice(-4)}` : ""}
          </span>
          <button
            onClick={() => disconnect()}
            className="bg-gradient-to-r from-pink-500 to-purple-500 hover:from-pink-400 hover:to-purple-400 text-white px-4 py-2 rounded-lg shadow font-semibold transition"
          >
            断开连接
          </button>
        </>
      ) : (
        <button
          onClick={() => open()}
          className="bg-gradient-to-r from-blue-500 to-green-500 hover:from-blue-400 hover:to-green-400 text-white px-6 py-2 rounded-lg shadow font-semibold transition"
        >
          连接钱包
        </button>
      )}
    </div>
  );
}

function DepositWithPermit({
  refetchErc20Balance,
  refetchBankBalance,
}: {
  refetchErc20Balance: () => void;
  refetchBankBalance: () => void;
}) {
  const [modalOpen, setModalOpen] = useState(false);
  const [modalStatus, setModalStatus] = useState<
    "pending" | "success" | "error" | null
  >(null);

  const { address, chain, chainId } = useAccount();
  const { data, error, isPending, isError, writeContract } = useWriteContract();
  const { data: receipt, isSuccess } = useWaitForTransactionReceipt({
    hash: data,
  });
  const {
    signTypedData,
    data: signature,
    isPending: isSigning,
  } = useSignTypedData();
  const [amount, setAmount] = useState<string>("");
  const [deadline, setDeadline] = useState<string>("");
  const [pendingAmount, setPendingAmount] = useState<string>("");
  const [pendingDeadline, setPendingDeadline] = useState<number>(0);

  // 获取 nonce
  const { data: nonce } = useReadContract({
    ...erc20PermitTokenContractConfig,
    functionName: "nonces",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  useEffect(() => {
    if (isPending) {
      setModalOpen(true);
      setModalStatus("pending");
    } else if (isSuccess) {
      setModalOpen(true);
      setModalStatus("success");
      setAmount("");
      setDeadline("");
      setPendingAmount("");
      setPendingDeadline(0);
      refetchErc20Balance && refetchErc20Balance();
      refetchBankBalance && refetchBankBalance();
    } else if (isError) {
      setModalOpen(true);
      setModalStatus("error");
    }
  }, [
    isPending,
    isSuccess,
    isError,
    refetchErc20Balance,
    refetchBankBalance,
    error,
  ]);

  const handleDepositWithPermit = async (amount: string) => {
    if (!address) {
      alert("请先连接钱包！");
      return;
    }
    if (!amount) {
      alert("请填写Token数量！");
      return;
    }

    // 默认有效期一小时
    const deadline = Math.floor(Date.now() / 1000) + 3600;

    // 保存待处理的参数
    setPendingAmount(amount);
    setPendingDeadline(deadline);

    try {
      // 构造需要签名的信息
      const domain = {
        name: "ERC20PermitToken",
        version: "1",
        chainId: chainId,
        verifyingContract: erc20PermitTokenContractConfig.address,
      };

      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      };

      const value = {
        owner: address,
        spender: tokenBankPermitContractConfig.address,
        value: parseEther(amount),
        nonce: nonce,
        deadline: deadline,
      };

      await signTypedData({
        domain,
        types,
        primaryType: "Permit",
        message: value,
      });
    } catch (error) {
      console.error("Permit deposit error:", error);
      alert("签名获取失败，请重试");
    }
  };

  // 当签名完成时，执行合约调用
  useEffect(() => {
    if (signature && pendingAmount && pendingDeadline) {
      console.log("签名完成，开始执行合约调用", {
        signature,
        pendingAmount,
        pendingDeadline,
      });

      // 解析签名为 r, s, v
      const { r, s, v } = parseSignature(signature);

      writeContract({
        ...tokenBankPermitContractConfig,
        functionName: "depositWithPermit",
        args: [
          parseEther(pendingAmount),
          BigInt(pendingDeadline),
          Number(v),
          r as `0x${string}`,
          s as `0x${string}`,
        ],
      });

      // 清空待处理参数
      setPendingAmount("");
      setPendingDeadline(0);
    }
  }, [signature, pendingAmount, pendingDeadline, writeContract]);

  return (
    <div className="bg-gray-900 rounded-2xl shadow-lg p-6 flex flex-col gap-4">
      <h2 className="text-xl font-bold mb-2 text-white">签名授权存款</h2>

      <div className="flex gap-2 items-center">
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="Token 数量"
          className="rounded-lg border border-gray-700 bg-black text-white px-4 py-2 w-40 shadow focus:ring-2 focus:ring-blue-400 placeholder-gray-400"
        />
        <button
          disabled={isPending}
          onClick={() => handleDepositWithPermit(amount)}
          className="rounded-lg bg-blue-600 text-white px-5 py-2 font-semibold shadow hover:bg-blue-400 transition"
        >
          授权存款
        </button>
      </div>

      <div className="w-full bg-gray-800 rounded-xl p-4 mt-2">
        <span className="font-bold text-white text-sm">说明：</span>
        <span className="text-white text-sm">
          基于 EIP2612 标准实现的签名授权存款功能，签名默认有效期一小时。
        </span>
      </div>

      <TxModal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
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

function DepositWithPermit2({
  refetchErc20Balance,
  refetchBankBalance,
}: {
  refetchErc20Balance: () => void;
  refetchBankBalance: () => void;
}) {
  const [modalOpen, setModalOpen] = useState(false);
  const [modalStatus, setModalStatus] = useState<
    "pending" | "success" | "error" | null
  >(null);

  const { address, chain, chainId } = useAccount();
  const { data, error, isPending, isError, writeContract } = useWriteContract();
  const { data: receipt, isSuccess } = useWaitForTransactionReceipt({
    hash: data,
  });
  const {
    signTypedData,
    data: signature,
    isPending: isSigning,
  } = useSignTypedData();
  const [amount, setAmount] = useState<string>("");
  const [pendingAmount, setPendingAmount] = useState<string>("");
  const [pendingDeadline, setPendingDeadline] = useState<number>(0);
  const [pendingNonce, setPendingNonce] = useState<bigint | undefined>(
    undefined
  );

  useEffect(() => {
    if (isPending) {
      setModalOpen(true);
      setModalStatus("pending");
    } else if (isSuccess) {
      setModalOpen(true);
      setModalStatus("success");
      setAmount("");
      setPendingAmount("");
      setPendingDeadline(0);
      setPendingNonce(undefined);
      refetchErc20Balance && refetchErc20Balance();
      refetchBankBalance && refetchBankBalance();
    } else if (isError) {
      setModalOpen(true);
      setModalStatus("error");
      // 清空待处理参数
      setPendingAmount("");
      setPendingDeadline(0);
      setPendingNonce(undefined);
      console.error("交易失败:", error);
    }
  }, [
    isPending,
    isSuccess,
    isError,
    refetchErc20Balance,
    refetchBankBalance,
    error,
  ]);

  const handleApprovePermit2 = (amount: string) => {
    if (!address) {
      alert("请先连接钱包！");
      return;
    }
    if (!amount) {
      alert("请填写Token数量！");
      return;
    }

    // 调用erc20合约的approve方法，授权permit2合约使用代币
    writeContract({
      ...erc20PermitTokenContractConfig,
      functionName: "approve",
      args: [permit2ContractConfig.address, parseEther(amount)],
    });
  };

  const handleDepositWithPermit = async (amount: string) => {
    if (!address) {
      alert("请先连接钱包！");
      return;
    }
    if (!amount) {
      alert("请填写Token数量！");
      return;
    }

    // Permit2 合约未提供合适的方法获取 nonce，这里使用随机数代替
    const nonce = BigInt(Math.floor(Math.random() * 1000000));

    // 默认有效期一小时
    const deadline = Math.floor(Date.now() / 1000) + 3600;

    // 保存待处理的参数
    setPendingAmount(amount);
    setPendingDeadline(deadline);
    setPendingNonce(nonce);

    try {
      // 构造需要签名的信息 - 使用正确的Permit2格式
      const domain = {
        name: "Permit2",
        version: "1",
        chainId: chainId,
        verifyingContract: permit2ContractConfig.address,
      };

      const types = {
        TokenPermissions: [
          { name: "token", type: "address" },
          { name: "amount", type: "uint256" },
        ],
        PermitSingle: [
          { name: "details", type: "PermitDetails" },
          { name: "spender", type: "address" },
          { name: "sigDeadline", type: "uint256" },
        ],
        PermitDetails: [
          { name: "token", type: "address" },
          { name: "amount", type: "uint256" },
          { name: "expiration", type: "uint256" },
          { name: "nonce", type: "uint256" },
        ],
      };

      const value = {
        details: {
          token: erc20PermitTokenContractConfig.address,
          amount: parseEther(amount),
          expiration: BigInt(deadline),
          nonce: nonce,
        },
        spender: tokenBankPermitContractConfig.address,
        sigDeadline: BigInt(deadline),
      };

      await signTypedData({
        domain,
        types,
        primaryType: "PermitSingle",
        message: value,
      });
    } catch (error) {
      console.error("Permit deposit error:", error);
      alert("签名获取失败，请重试");

      setPendingAmount("");
      setPendingDeadline(0);
      setPendingNonce(undefined);
    }
  };

  // 当签名完成时，执行合约调用
  useEffect(() => {
    if (
      signature &&
      pendingAmount &&
      pendingDeadline &&
      pendingNonce !== undefined
    ) {
      console.log("签名完成，开始执行合约调用", {
        signature,
        pendingAmount,
        pendingDeadline,
        pendingNonce,
      });

      writeContract({
        ...tokenBankPermitContractConfig,
        functionName: "depositWithPermit2",
        args: [
          parseEther(pendingAmount),
          pendingNonce,
          BigInt(pendingDeadline),
          signature,
        ],
      });

      // 清空待处理参数
      setPendingAmount("");
      setPendingDeadline(0);
      setPendingNonce(undefined);
    }
  }, [signature, pendingAmount, pendingDeadline, pendingNonce, writeContract]);

  return (
    <div className="bg-gray-900 rounded-2xl shadow-lg p-6 flex flex-col gap-4">
      <h2 className="text-xl font-bold mb-2 text-white">
        Permit2 签名授权存款
      </h2>

      <div className="flex gap-2 items-center">
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="Token 数量"
          className="rounded-lg border border-gray-700 bg-black text-white px-4 py-2 w-40 shadow focus:ring-2 focus:ring-blue-400 placeholder-gray-400"
        />
        <button
          disabled={isPending}
          onClick={() => handleDepositWithPermit(amount)}
          className="rounded-lg bg-blue-600 text-white px-5 py-2 font-semibold shadow hover:bg-blue-400 transition"
        >
          授权存款（Permit2）
        </button>
      </div>
      <div className="flex gap-2 items-center">
        <button
          disabled={isPending}
          onClick={() => handleApprovePermit2(amount)}
          className="rounded-lg bg-yellow-600 text-white px-4 py-2 font-semibold shadow hover:bg-yellow-400 transition"
        >
          授权Permit2合约
        </button>
      </div>

      <div className="w-full bg-gray-800 rounded-xl p-4 mt-2">
        <span className="font-bold text-white text-sm">说明：</span>
        <span className="text-white text-sm">
          先点击"授权Permit2"允许Permit2合约使用您的代币，再点击"授权存款（Permit2）"进行签名存款，签名默认有效期一小时。
        </span>
      </div>

      <TxModal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
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

function DepositToBank({
  refetchErc20Balance,
  refetchBankBalance,
}: {
  refetchErc20Balance: () => void;
  refetchBankBalance: () => void;
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
      refetchBankBalance && refetchBankBalance();
    } else if (isError) {
      setModalOpen(true);
      setModalStatus("error");
    }
  }, [isPending, isSuccess, isError, refetchErc20Balance, refetchBankBalance]);

  const handleApprove = (amount: string) => {
    if (!address) {
      alert("请先连接钱包！");
      return;
    }
    if (!amount) {
      alert("请填写Token数量！");
      return;
    }
    writeContract({
      ...erc20PermitTokenContractConfig,
      functionName: "approve",
      args: [tokenBankPermitContractConfig.address, parseEther(amount)],
    });
  };

  const handleDeposit = (amount: string) => {
    if (!address) {
      alert("请先连接钱包！");
      return;
    }
    if (!amount) {
      alert("请填写Token数量！");
      return;
    }
    writeContract({
      ...tokenBankPermitContractConfig,
      functionName: "deposit",
      args: [parseEther(amount)],
    });
  };

  return (
    <div className="bg-gray-900 rounded-2xl shadow-lg p-6 flex flex-col gap-4">
      <h2 className="text-xl font-bold mb-2 text-white">银行存款</h2>
      <div className="flex gap-2 items-center">
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="Token 数量"
          className="rounded-lg border border-gray-700 bg-black text-white px-4 py-2 w-40 shadow focus:ring-2 focus:ring-green-400 placeholder-gray-400"
        />
        <button
          onClick={() => handleApprove(amount)}
          className="rounded-lg bg-yellow-600 text-white px-4 py-2 font-semibold shadow hover:bg-yellow-400 transition whitespace-nowrap"
        >
          授权
        </button>
        <button
          onClick={() => handleDeposit(amount)}
          className="rounded-lg bg-green-600 text-white px-4 py-2 font-semibold shadow hover:bg-green-400 transition whitespace-nowrap"
        >
          存款
        </button>
      </div>
      <div className="w-full bg-gray-800 rounded-xl p-4 mt-2">
        <span className="font-bold text-white text-sm">说明：</span>
        <span className="text-white text-sm">
          先点击"授权"允许银行使用您的代币，再点击"存款"将代币存入银行
        </span>
      </div>
      <TxModal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
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

function WithdrawFromBank({
  refetchErc20Balance,
  refetchBankBalance,
}: {
  refetchErc20Balance: () => void;
  refetchBankBalance: () => void;
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
      refetchBankBalance && refetchBankBalance();
    } else if (isError) {
      setModalOpen(true);
      setModalStatus("error");
    }
  }, [isPending, isSuccess, isError, refetchErc20Balance, refetchBankBalance]);

  const handleWithdraw = (amount: string) => {
    if (!address) {
      alert("请先连接钱包！");
      return;
    }
    if (!amount) {
      alert("请填写Token数量！");
      return;
    }
    writeContract({
      ...tokenBankPermitContractConfig,
      functionName: "withdraw",
      args: [parseEther(amount)],
    });
  };

  return (
    <div className="bg-gray-900 rounded-2xl shadow-lg p-6 flex flex-col gap-4">
      <h2 className="text-xl font-bold mb-2 text-white">银行取款</h2>
      <div className="flex gap-2 items-center">
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="Token 数量"
          className="rounded-lg border border-gray-700 bg-black text-white px-4 py-2 w-40 shadow focus:ring-2 focus:ring-red-400 placeholder-gray-400"
        />
        <button
          onClick={() => handleWithdraw(amount)}
          className="rounded-lg bg-red-600 text-white px-4 py-2 font-semibold shadow hover:bg-red-400 transition whitespace-nowrap"
        >
          取款
        </button>
      </div>
      <div className="w-full bg-gray-800 rounded-xl p-4 mt-2">
        <span className="font-bold text-white text-sm">说明：</span>
        <span className="text-white text-sm">
          从银行取出您的代币，取款后代币将直接转入您的钱包
        </span>
      </div>
      <TxModal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
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
      <div className="bg-gray-900 rounded-2xl shadow-lg p-8 min-w-[320px] max-w-lg text-white relative">
        <button
          className="absolute top-2 right-4 text-gray-400 hover:text-white text-2xl font-bold"
          onClick={props.onClose}
        >
          ×
        </button>
        {props.status === "pending" && (
          <div className="mb-2">正在发送交易，请稍等...</div>
        )}
        {props.status === "success" && (
          <>
            <div className="mb-2 text-green-400 font-bold">交易成功！</div>
            {props.amount && <div>交易成功，amount: {props.amount}</div>}
            {props.hash && props.chain && (
              <a
                target="_blank"
                rel="noopener noreferrer"
                href={`${props.chain?.blockExplorers?.default?.url}/tx/${props.hash}`}
                className="underline text-blue-400 break-all"
              >
                交易哈希: {props.hash}
              </a>
            )}
            {props.receipt && (
              <div className="mt-2 max-h-40 overflow-auto bg-gray-800 rounded p-2 text-xs">
                交易回执: <pre>{stringify(props.receipt, null, 2)}</pre>
              </div>
            )}
            <div className="mt-4 flex justify-center">
              <button
                onClick={props.onClose}
                className="bg-green-600 hover:bg-green-500 text-white px-6 py-2 rounded-lg font-semibold transition"
              >
                确定
              </button>
            </div>
          </>
        )}
        {props.status === "error" && (
          <div className="text-red-400 font-bold">
            {props.error?.message || "交易失败"}
          </div>
        )}
      </div>
    </div>
  );
}
