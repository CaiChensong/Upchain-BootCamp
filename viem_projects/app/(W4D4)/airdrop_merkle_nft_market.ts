import {
  createPublicClient,
  http,
  createWalletClient,
  parseEther,
  encodeFunctionData,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { foundry } from "viem/chains";
import { MerkleTree } from "merkletreejs";
import keccak256Lib from "keccak256";
import MARKET_ABI from "./abi/AirdopMerkleNFTMarket.json" with { type: "json" };
import TOKEN_ABI from "./abi/AirdropToken.json" with { type: "json" };
import NFT_ABI from "./abi/AirdropNFT.json" with { type: "json" };

const MARKET_CONTRACT_ADDRESS = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"; // AirdopMerkleNFTMarket 合约地址
const TOKEN_CONTRACT_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // AirdropToken 合约地址
const NFT_CONTRACT_ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"; // AirdropNFT 合约地址

const OWNER_PRIVATE_KEY =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"; // owner 私钥
const WHITELIST_USER1_PRIVATE_KEY =
  "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"; // 使用 Foundry 默认账户 0 的私钥

const SELLER_ADDRESS = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
const WHITELIST_USER1_ADDRESS = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"; // Foundry 默认账户 0 的地址
const WHITELIST_USER2_ADDRESS = "0x90F79bf6EB2c4f870365E785982E1f101E93b906";
const WHITELIST_USER3_ADDRESS = "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65";

// 创建客户端
const publicClient = createPublicClient({
  chain: foundry,
  transport: http("http://127.0.0.1:8545"),
});

const walletClient = createWalletClient({
  chain: foundry,
  transport: http("http://127.0.0.1:8545"),
});

// 创建账户
const ownerAccount = privateKeyToAccount(OWNER_PRIVATE_KEY as `0x${string}`);
const whitelistUser1Account = privateKeyToAccount(
  WHITELIST_USER1_PRIVATE_KEY as `0x${string}`
);

const whitelistAddresses = [
  WHITELIST_USER1_ADDRESS,
  WHITELIST_USER2_ADDRESS,
  WHITELIST_USER3_ADDRESS,
];

const tree = buildMerkleTree(whitelistAddresses);

// 生成 permit 签名
async function generatePermitSignature(
  owner: string,
  spender: string,
  amount: bigint,
  deadline: bigint
): Promise<{ v: number; r: `0x${string}`; s: `0x${string}` }> {
  // 获取 nonce
  const nonce = await publicClient.readContract({
    address: TOKEN_CONTRACT_ADDRESS as `0x${string}`,
    abi: TOKEN_ABI,
    functionName: "nonces",
    args: [owner as `0x${string}`],
  });

  // 构造需要签名的信息
  const domain = {
    name: "AirdropToken",
    version: "1",
    chainId: foundry.id,
    verifyingContract: TOKEN_CONTRACT_ADDRESS as `0x${string}`,
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
    owner: owner,
    spender: spender,
    value: amount,
    nonce: nonce,
    deadline: deadline,
  };

  const signature = await walletClient.signTypedData({
    account: whitelistUser1Account,
    domain,
    types,
    primaryType: "Permit",
    message: value,
  });

  // 解析签名
  const r = signature.slice(0, 66) as `0x${string}`;
  const s = `0x${signature.slice(66, 130)}` as `0x${string}`;
  const v = parseInt(signature.slice(130, 132), 16);

  return { v, r, s };
}

// 构建默克尔树
function buildMerkleTree(whitelistAddresses: string[]) {
  // 创建叶子节点（地址的 keccak256 哈希）
  const leaves = whitelistAddresses.map((addr) => keccak256Lib(addr));

  // 创建默克尔树
  const tree = new MerkleTree(leaves, keccak256Lib, { sortPairs: true });

  return tree;
}

// 准备工作：mint token、铸造NFT、上架NFT
async function prepareContracts() {
  console.log("开始准备工作...\n");

  try {
    // 1. 检查并给买家分配代币
    console.log("1. 检查买家代币余额...");
    const buyerBalance = (await publicClient.readContract({
      address: TOKEN_CONTRACT_ADDRESS as `0x${string}`,
      abi: TOKEN_ABI,
      functionName: "balanceOf",
      args: [WHITELIST_USER1_ADDRESS as `0x${string}`],
    })) as bigint;

    console.log(`买家当前余额: ${buyerBalance} wei`);

    if (buyerBalance < parseEther("1000")) {
      console.log("给买家分配代币...");
      const transferHash = await walletClient.writeContract({
        address: TOKEN_CONTRACT_ADDRESS as `0x${string}`,
        abi: TOKEN_ABI,
        functionName: "transfer",
        args: [WHITELIST_USER1_ADDRESS as `0x${string}`, parseEther("1000")],
        account: ownerAccount,
      });
      await publicClient.waitForTransactionReceipt({ hash: transferHash });
      console.log(`代币分配成功，交易哈希: ${transferHash}`);
    }

    // 2. 检查并给卖家分配代币和NFT
    console.log("\n2. 检查卖家余额和NFT...");
    const sellerBalance = (await publicClient.readContract({
      address: TOKEN_CONTRACT_ADDRESS as `0x${string}`,
      abi: TOKEN_ABI,
      functionName: "balanceOf",
      args: [SELLER_ADDRESS as `0x${string}`],
    })) as bigint;

    console.log(`卖家当前余额: ${sellerBalance} wei`);

    if (sellerBalance < parseEther("1000")) {
      console.log("给卖家分配代币...");
      const transferHash = await walletClient.writeContract({
        address: TOKEN_CONTRACT_ADDRESS as `0x${string}`,
        abi: TOKEN_ABI,
        functionName: "transfer",
        args: [SELLER_ADDRESS as `0x${string}`, parseEther("1000")],
        account: ownerAccount,
      });
      await publicClient.waitForTransactionReceipt({ hash: transferHash });
      console.log(`代币分配成功，交易哈希: ${transferHash}`);
    }

    // 3. 铸造NFT给卖家
    console.log("\n3. 铸造NFT给卖家...");
    const totalSupply = (await publicClient.readContract({
      address: NFT_CONTRACT_ADDRESS as `0x${string}`,
      abi: NFT_ABI,
      functionName: "totalSupply",
    })) as bigint;

    console.log(`当前NFT总供应量: ${totalSupply}`);

    if (totalSupply < BigInt(2)) {
      console.log("铸造NFT...");
      const mintHash1 = await walletClient.writeContract({
        address: NFT_CONTRACT_ADDRESS as `0x${string}`,
        abi: NFT_ABI,
        functionName: "mint",
        args: [SELLER_ADDRESS as `0x${string}`],
        account: ownerAccount,
      });
      await publicClient.waitForTransactionReceipt({ hash: mintHash1 });
      console.log(`NFT 0 铸造成功，交易哈希: ${mintHash1}`);

      const mintHash2 = await walletClient.writeContract({
        address: NFT_CONTRACT_ADDRESS as `0x${string}`,
        abi: NFT_ABI,
        functionName: "mint",
        args: [SELLER_ADDRESS as `0x${string}`],
        account: ownerAccount,
      });
      await publicClient.waitForTransactionReceipt({ hash: mintHash2 });
      console.log(`NFT 1 铸造成功，交易哈希: ${mintHash2}`);
    }

    // 4. 检查NFT上架状态
    console.log("\n4. 检查NFT上架状态...");
    const listing = (await publicClient.readContract({
      address: MARKET_CONTRACT_ADDRESS as `0x${string}`,
      abi: MARKET_ABI,
      functionName: "listings",
      args: [BigInt(0)],
    })) as [string, string, bigint, boolean];

    const [listOwner, nftToken, price, isActive] = listing;
    console.log(
      `NFT 0 上架状态: 所有者=${listOwner}, 价格=${price}, 激活=${isActive}`
    );

    if (!isActive) {
      console.log("上架NFT...");

      // 卖家授权NFT市场合约
      const approveHash = await walletClient.writeContract({
        address: NFT_CONTRACT_ADDRESS as `0x${string}`,
        abi: NFT_ABI,
        functionName: "approve",
        args: [MARKET_CONTRACT_ADDRESS as `0x${string}`, BigInt(0)],
        account: privateKeyToAccount(
          "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" as `0x${string}`
        ), // seller私钥
      });
      await publicClient.waitForTransactionReceipt({ hash: approveHash });
      console.log(`NFT授权成功，交易哈希: ${approveHash}`);

      // 上架NFT
      const listHash = await walletClient.writeContract({
        address: MARKET_CONTRACT_ADDRESS as `0x${string}`,
        abi: MARKET_ABI,
        functionName: "listNFT",
        args: [
          NFT_CONTRACT_ADDRESS as `0x${string}`,
          BigInt(0),
          parseEther("100"),
        ],
        account: privateKeyToAccount(
          "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" as `0x${string}`
        ), // seller私钥
      });
      await publicClient.waitForTransactionReceipt({ hash: listHash });
      console.log(`NFT上架成功，交易哈希: ${listHash}`);

      // 将NFT转移到市场合约
      const transferHash = await walletClient.writeContract({
        address: NFT_CONTRACT_ADDRESS as `0x${string}`,
        abi: NFT_ABI,
        functionName: "transferFrom",
        args: [
          SELLER_ADDRESS as `0x${string}`,
          MARKET_CONTRACT_ADDRESS as `0x${string}`,
          BigInt(0),
        ],
        account: privateKeyToAccount(
          "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" as `0x${string}`
        ), // seller私钥
      });
      await publicClient.waitForTransactionReceipt({ hash: transferHash });
      console.log(`NFT转移到市场合约成功，交易哈希: ${transferHash}`);
    }

    // 5. 设置默克尔根
    console.log("\n5. 设置默克尔根...");

    const merkleRoot = tree.getRoot();

    const updateHash = await walletClient.writeContract({
      address: MARKET_CONTRACT_ADDRESS as `0x${string}`,
      abi: MARKET_ABI,
      functionName: "updateMerkleRoot",
      args: [("0x" + merkleRoot.toString("hex")) as `0x${string}`],
      account: ownerAccount,
    });
    await publicClient.waitForTransactionReceipt({ hash: updateHash });
    console.log(`默克尔根设置成功，交易哈希: ${updateHash}`);
    console.log(`默克尔根: ${merkleRoot.toString("hex")}`);

    console.log("\n准备工作完成！");
  } catch (error) {
    console.error("准备工作失败:", error);
    throw error;
  }
}

// 测试 multicall 方法
async function testMulticall() {
  try {
    console.log("开始测试 multicall 方法...\n");

    // 1. 取用户1的证明
    console.log("1. 取用户1的证明...");

    const leaf1 = keccak256Lib(WHITELIST_USER1_ADDRESS);
    const proof1 = tree.getProof(leaf1);
    const proof1Hex = proof1.map(
      (p) => "0x" + p.data.toString("hex")
    ) as `0x${string}`[];
    console.log("用户1的证明:", proof1Hex);

    // 2. 生成 permit 签名
    console.log("\n2. 生成 permit 签名...");
    const nftPrice = parseEther("100"); // 100 ether
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1小时后过期

    const { v, r, s } = await generatePermitSignature(
      WHITELIST_USER1_ADDRESS,
      MARKET_CONTRACT_ADDRESS,
      nftPrice, // 完整价格
      deadline
    );
    console.log("Permit 签名生成完成");

    // 3. 准备 multicall 数据
    console.log("\n3. 准备 multicall 数据...");

    // 第一个调用：permitPrePay
    const permitPrePayData = encodeFunctionData({
      abi: MARKET_ABI,
      functionName: "permitPrePay",
      args: [BigInt(0), nftPrice, deadline, v, r, s],
    });

    // 第二个调用：claimNFT
    const claimNFTData = encodeFunctionData({
      abi: MARKET_ABI,
      functionName: "claimNFT",
      args: [BigInt(0), proof1Hex],
    });

    const calls = [
      {
        target: MARKET_CONTRACT_ADDRESS as `0x${string}`,
        allowFailure: false,
        callData: permitPrePayData,
      },
      {
        target: MARKET_CONTRACT_ADDRESS as `0x${string}`,
        allowFailure: false,
        callData: claimNFTData,
      },
    ];

    // 4. 执行 multicall
    console.log("\n4. 执行 multicall...");
    const hash = await walletClient.writeContract({
      address: MARKET_CONTRACT_ADDRESS as `0x${string}`,
      abi: MARKET_ABI,
      functionName: "multicall",
      args: [calls],
      account: whitelistUser1Account,
    });

    console.log("Multicall 交易已发送，哈希:", hash);

    // 5. 等待交易确认
    console.log("\n5. 等待交易确认...");
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log("交易已确认，区块号:", receipt.blockNumber);

    // 6. 解析结果
    console.log("\n6. 解析 multicall 结果...");
    const logs = receipt.logs;

    // 查找 multicall 的返回数据
    for (const log of logs) {
      if (log.address.toLowerCase() === MARKET_CONTRACT_ADDRESS.toLowerCase()) {
        console.log("找到市场合约事件:", log);
      }
    }

    console.log("\nMulticall 测试完成！");
  } catch (error) {
    console.error("Multicall 测试失败:", error);
  }
}

// 主函数
async function main() {
  console.log("开始测试 AirdopMerkleNFTMarket 合约的 multicall 方法\n");

  // 准备工作
  await prepareContracts();

  // 测试 multicall
  await testMulticall();
}

// 运行脚本
main().catch(console.error);
