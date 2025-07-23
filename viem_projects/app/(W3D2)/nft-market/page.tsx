"use client";

/*
题目#1 DApp 接入 AppKit 登录

为 NFTMarket 项目添加前端，并接入 AppKit 进行前端登录，并实际操作使用 WalletConnect 进行登录（需要先安装手机端钱包）。

并在 NFTMarket 前端添加上架操作，切换另一个账号后可使用 Token 进行购买 NFT。

提交 github 仓库地址，请在仓库中包含 NFT 上架后的截图。
*/

import ERC20_ABI from "./abi/MockERC20.json" with { type: "json" };
import ERC721_ABI from "./abi/MockERC721.json" with { type: "json" };
import NFT_MARKET_ABI from "./abi/NFTMarket.json" with { type: "json" };
import { stringify, parseEther } from "viem";
import { useState, useEffect } from "react";
import { useAppKit } from "@reown/appkit/react";
import {
  useAccount,
  useDisconnect,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";

export default function Home() {
  const { address } = useAccount();

  const { data: erc20Balance, refetch: refetchErc20Balance } = useReadContract({
    ...erc20ContractConfig,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const { data: nftBalance, refetch: refetchNftBalance } = useReadContract({
    ...erc721ContractConfig,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  return (
    <div className="min-h-screen bg-black flex flex-col items-center py-12">
      <h1 className="text-4xl font-extrabold text-center mb-10 bg-gradient-to-r from-blue-400 to-purple-400 text-transparent bg-clip-text drop-shadow-lg">
        NFT Market Demo
      </h1>
      <div className="w-full max-w-3xl flex flex-col md:flex-row gap-8 mb-10 justify-center">
        <div className="flex-1 flex flex-col gap-4 max-w-md w-full">
          <MintERC20Token
            erc20Balance={erc20Balance}
            refetchErc20Balance={refetchErc20Balance}
          />
        </div>
        <div className="flex-1 flex flex-col gap-4 max-w-md w-full">
          <MintNFT
            nftBalance={nftBalance}
            refetchNftBalance={refetchNftBalance}
          />
        </div>
      </div>
      <div className="w-full max-w-3xl flex flex-col gap-8 items-center">
        <div className="w-full max-w-3xl">
          <ListNFT
            refetchErc20Balance={refetchErc20Balance}
            refetchNftBalance={refetchNftBalance}
          />
        </div>
        <div className="w-full max-w-3xl">
          <BuyNFT
            refetchErc20Balance={refetchErc20Balance}
            refetchNftBalance={refetchNftBalance}
          />
        </div>
      </div>
      <ConnectWallet />
    </div>
  );
}

const erc20ContractConfig = {
  address: "0x5fbdb2315678afecb367f032d93f642f64180aa3" as `0x${string}`,
  abi: ERC20_ABI,
};

const erc721ContractConfig = {
  address: "0xe7f1725e7734ce288f8367e1bb143e90bb3f0512" as `0x${string}`,
  abi: ERC721_ABI,
};

const nftMarketContractConfig = {
  address: "0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0" as `0x${string}`,
  abi: NFT_MARKET_ABI,
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

type TxModalProps = {
  open: boolean;
  onClose: () => void;
  status: "pending" | "success" | "error" | null;
  hash?: string;
  receipt?: any;
  error?: any;
  chain?: any;
  amount?: string;
  tokenId?: string;
  price?: string;
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
            {props.amount && <div>充值成功，amount: {props.amount}</div>}
            {props.tokenId && (
              <div>铸造/上架/购买成功，tokenId: {props.tokenId}</div>
            )}
            {props.price && <div>价格: {props.price} ether</div>}
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

function MintERC20Token({
  erc20Balance,
  refetchErc20Balance,
}: {
  erc20Balance: any;
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

  useEffect(() => {
    if (isPending) {
      setModalOpen(true);
      setModalStatus("pending");
    } else if (isSuccess) {
      setModalOpen(true);
      setModalStatus("success");
      setAmount("");
      refetchErc20Balance && refetchErc20Balance();
    } else if (isError) {
      setModalOpen(true);
      setModalStatus("error");
    }
  }, [isPending, isSuccess, isError, refetchErc20Balance]);

  const handleMint = (amount: string) => {
    if (!address) {
      alert("请先连接钱包！");
      return;
    }
    if (!amount) {
      alert("请填写Token充值数量！");
      return;
    }
    writeContract({
      ...erc20ContractConfig,
      functionName: "mint",
      args: [address, parseEther(amount)],
    });
  };

  return (
    <div className="bg-gray-900 rounded-2xl shadow-lg p-6 flex flex-col gap-4">
      <h2 className="text-xl font-bold mb-2 text-white">Token 充值</h2>
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
          onClick={() => handleMint(amount)}
          className="rounded-lg bg-blue-600 text-white px-5 py-2 font-semibold shadow hover:bg-blue-400 transition"
        >
          充值
        </button>
      </div>
      <div className="w-full bg-gray-800 rounded-xl p-4 mt-2">
        <span className="font-bold text-white">Token 余额：</span>
        <span className="text-white">
          {erc20Balance ? Number(erc20Balance) / 1e18 : "--"} Token
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

function MintNFT({
  nftBalance,
  refetchNftBalance,
}: {
  nftBalance: any;
  refetchNftBalance: () => void;
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
  const [tokenId, setTokenId] = useState<string>("");

  useEffect(() => {
    if (isPending) {
      setModalOpen(true);
      setModalStatus("pending");
    } else if (isSuccess) {
      setModalOpen(true);
      setModalStatus("success");
      setTokenId("");
      refetchNftBalance && refetchNftBalance();
    } else if (isError) {
      setModalOpen(true);
      setModalStatus("error");
    }
  }, [isPending, isSuccess, isError, refetchNftBalance]);

  const handleMint = (tokenId: string) => {
    if (!address) {
      alert("请先连接钱包！");
      return;
    }
    if (!tokenId) {
      alert("请填写NFT的tokenId！");
      return;
    }
    writeContract({
      ...erc721ContractConfig,
      functionName: "safeMint",
      args: [address, BigInt(tokenId)],
    });
  };

  return (
    <div className="bg-gray-900 rounded-2xl shadow-lg p-6 flex flex-col gap-4">
      <h2 className="text-xl font-bold mb-2 text-white">铸造 NFT</h2>
      <div className="flex gap-2 items-center">
        <input
          type="number"
          value={tokenId}
          onChange={(e) => setTokenId(e.target.value)}
          placeholder="NFT tokenId"
          className="rounded-lg border border-gray-700 bg-black text-white px-4 py-2 w-40 shadow focus:ring-2 focus:ring-blue-400 placeholder-gray-400"
        />
        <button
          disabled={isPending}
          onClick={() => handleMint(tokenId)}
          className="rounded-lg bg-blue-600 text-white px-5 py-2 font-semibold shadow hover:bg-blue-400 transition"
        >
          铸造
        </button>
      </div>
      <div className="w-full bg-gray-800 rounded-xl p-4 mt-2">
        <span className="font-bold text-white">NFT 数量：</span>
        <span className="text-white">
          {nftBalance ? Number(nftBalance) : "--"} NFT
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
        tokenId={tokenId}
      />
    </div>
  );
}

function ListNFT({
  refetchErc20Balance,
  refetchNftBalance,
}: {
  refetchErc20Balance: () => void;
  refetchNftBalance: () => void;
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
  const [tokenId, setTokenId] = useState<string>("");
  const [price, setPrice] = useState<string>("");

  useEffect(() => {
    if (isPending) {
      setModalOpen(true);
      setModalStatus("pending");
    } else if (isSuccess) {
      setModalOpen(true);
      setModalStatus("success");
      setTokenId("");
      setPrice("");
      refetchErc20Balance && refetchErc20Balance();
      refetchNftBalance && refetchNftBalance();
    } else if (isError) {
      setModalOpen(true);
      setModalStatus("error");
    }
  }, [isPending, isSuccess, isError, refetchErc20Balance, refetchNftBalance]);

  const handleApprove = (tokenId: string, price: string) => {
    if (!address) {
      alert("请先连接钱包！");
      return;
    }
    if (!tokenId || !price) {
      alert("请填写NFT的tokenId和价格！");
      return;
    }
    writeContract({
      ...erc721ContractConfig,
      functionName: "approve",
      args: [nftMarketContractConfig.address, BigInt(tokenId)],
    });
  };

  const handleList = (tokenId: string, price: string) => {
    if (!address) {
      alert("请先连接钱包！");
      return;
    }
    if (!tokenId || !price) {
      alert("请填写NFT的tokenId和价格！");
      return;
    }
    writeContract({
      ...nftMarketContractConfig,
      functionName: "list",
      args: [BigInt(tokenId), parseEther(price)],
    });
  };

  return (
    <div className="bg-gray-900 rounded-2xl shadow-lg p-6 flex flex-col gap-4">
      <h2 className="text-xl font-bold mb-2 text-white">上架 NFT</h2>
      <div className="flex gap-2 items-center">
        <input
          type="number"
          value={tokenId}
          onChange={(e) => setTokenId(e.target.value)}
          placeholder="NFT tokenId"
          className="rounded-lg border border-gray-700 bg-black text-white px-4 py-2 w-60 shadow focus:ring-2 focus:ring-green-400 placeholder-gray-400"
        />
        <input
          type="number"
          value={price}
          onChange={(e) => setPrice(e.target.value)}
          placeholder="上架价格"
          className="rounded-lg border border-gray-700 bg-black text-white px-4 py-2 w-60 shadow focus:ring-2 focus:ring-green-400 placeholder-gray-400"
        />
        <button
          onClick={() => handleApprove(tokenId, price)}
          className="rounded-lg bg-green-600 text-white px-5 py-2 font-semibold shadow hover:bg-green-400 transition"
        >
          授权
        </button>
        <button
          onClick={() => handleList(tokenId, price)}
          className="rounded-lg bg-green-600 text-white px-5 py-2 font-semibold shadow hover:bg-green-400 transition"
        >
          上架
        </button>
      </div>
      <TxModal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        status={modalStatus}
        hash={data}
        receipt={receipt}
        error={error}
        chain={chain}
        tokenId={tokenId}
        price={price}
      />
    </div>
  );
}

function BuyNFT({
  refetchErc20Balance,
  refetchNftBalance,
}: {
  refetchErc20Balance: () => void;
  refetchNftBalance: () => void;
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
  const [tokenId, setTokenId] = useState<string>("");
  const [price, setPrice] = useState<string>("");

  useEffect(() => {
    if (isPending) {
      setModalOpen(true);
      setModalStatus("pending");
    } else if (isSuccess) {
      setModalOpen(true);
      setModalStatus("success");
      setTokenId("");
      setPrice("");
      refetchErc20Balance && refetchErc20Balance();
      refetchNftBalance && refetchNftBalance();
    } else if (isError) {
      setModalOpen(true);
      setModalStatus("error");
    }
  }, [isPending, isSuccess, isError, refetchErc20Balance, refetchNftBalance]);

  const handleApprove = (tokenId: string, price: string) => {
    if (!address) {
      alert("请先连接钱包！");
      return;
    }
    if (!tokenId || !price) {
      alert("请填写NFT的tokenId和价格！");
      return;
    }
    writeContract({
      ...erc20ContractConfig,
      functionName: "approve",
      args: [nftMarketContractConfig.address, parseEther(price)],
    });
  };

  const handleBuy = (tokenId: string, price: string) => {
    if (!address) {
      alert("请先连接钱包！");
      return;
    }
    if (!tokenId || !price) {
      alert("请填写NFT的tokenId和价格！");
      return;
    }
    writeContract({
      ...nftMarketContractConfig,
      functionName: "buy",
      args: [BigInt(tokenId), parseEther(price)],
    });
  };

  return (
    <div className="bg-gray-900 rounded-2xl shadow-lg p-6 flex flex-col gap-4">
      <h2 className="text-xl font-bold mb-2 text-white">购买 NFT</h2>
      <div className="flex gap-2 items-center">
        <input
          type="number"
          value={tokenId}
          onChange={(e) => setTokenId(e.target.value)}
          placeholder="NFT tokenId"
          className="rounded-lg border border-gray-700 bg-black text-white px-4 py-2 w-60 shadow focus:ring-2 focus:ring-green-400 placeholder-gray-400"
        />
        <input
          type="number"
          value={price}
          onChange={(e) => setPrice(e.target.value)}
          placeholder="购买价格"
          className="rounded-lg border border-gray-700 bg-black text-white px-4 py-2 w-60 shadow focus:ring-2 focus:ring-green-400 placeholder-gray-400"
        />
        <button
          onClick={() => handleApprove(tokenId, price)}
          className="rounded-lg bg-green-600 text-white px-5 py-2 font-semibold shadow hover:bg-green-400 transition"
        >
          授权
        </button>
        <button
          onClick={() => handleBuy(tokenId, price)}
          className="rounded-lg bg-green-600 text-white px-5 py-2 font-semibold shadow hover:bg-green-400 transition"
        >
          购买
        </button>
      </div>
      <TxModal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        status={modalStatus}
        hash={data}
        receipt={receipt}
        error={error}
        chain={chain}
        tokenId={tokenId}
        price={price}
      />
    </div>
  );
}
