import {
  createPublicClient,
  http,
  createWalletClient,
  parseEther,
  encodeFunctionData,
  decodeFunctionData,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { foundry } from "viem/chains";
import { keccak256, toHex, toBytes, concat, encodePacked } from "viem";
import ERC20_PERMIT_TOKEN_ABI from "./abi/ERC20PermitToken.json" with { type: "json" };
import NFT_MARKET_PERMIT_ABI from "./abi/NFTMarketPermit.json" with { type: "json" };
import PERMIT_NFT_ABI from "./abi/PermitNFT.json" with { type: "json" };

// 合约地址
const ERC20_PERMIT_TOKEN_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const PERMIT_NFT_ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
const NFT_MARKET_PERMIT_ADDRESS = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";

// 项目方私钥（用于签名）
const PROJECT_OWNER_PRIVATE_KEY =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

// 白名单用户私钥（卖家）
const WHITELIST_USER_PRIVATE_KEY =
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";

// 白名单用户私钥（买家）
const WHITELIST_BUYER_PRIVATE_KEY =
  "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a";

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
const projectOwner = privateKeyToAccount(
  PROJECT_OWNER_PRIVATE_KEY as `0x${string}`
);
const whitelistUser = privateKeyToAccount(
  WHITELIST_USER_PRIVATE_KEY as `0x${string}`
);
const whitelistBuyer = privateKeyToAccount(
  WHITELIST_BUYER_PRIVATE_KEY as `0x${string}`
);

// 白名单管理
const WHITELIST_ADDRESSES = [
  whitelistUser.address,
  whitelistBuyer.address,
  // 可以添加更多白名单地址
];

// 检查地址是否在白名单中
function isWhitelisted(address: string): boolean {
  return WHITELIST_ADDRESSES.includes(address as `0x${string}`);
}

// 生成签名
async function generatePermitSignature(
  buyer: string,
  tokenId: bigint,
  amount: bigint,
  deadline: bigint,
  contractAddress: string
): Promise<{ v: number; r: `0x${string}`; s: `0x${string}` }> {
  // 构造消息哈希 - 使用encodePacked模拟Solidity的abi.encodePacked
  const messageHash = keccak256(
    encodePacked(
      ["address", "uint256", "uint256", "uint256", "address"],
      [
        buyer as `0x${string}`,
        tokenId,
        amount,
        deadline,
        contractAddress as `0x${string}`,
      ]
    )
  );

  // 使用项目方私钥直接签名原始消息哈希
  // walletClient.signMessage 会自动添加以太坊前缀
  const signature = await walletClient.signMessage({
    account: projectOwner,
    message: { raw: messageHash },
  });

  // 解析签名
  const r = signature.slice(0, 66) as `0x${string}`;
  const s = `0x${signature.slice(66, 130)}` as `0x${string}`;
  const v = parseInt(signature.slice(130, 132), 16);

  return { v, r, s };
}

// 主要测试函数
async function testPermitBuy() {
  console.log("=== NFTMarket PermitBuy 测试开始 ===");

  try {
    // 1. 检查白名单用户余额
    const sellerBalance = await publicClient.readContract({
      address: ERC20_PERMIT_TOKEN_ADDRESS as `0x${string}`,
      abi: ERC20_PERMIT_TOKEN_ABI,
      functionName: "balanceOf",
      args: [whitelistUser.address],
    });
    console.log(`卖家余额: ${sellerBalance} wei`);

    const buyerBalance = await publicClient.readContract({
      address: ERC20_PERMIT_TOKEN_ADDRESS as `0x${string}`,
      abi: ERC20_PERMIT_TOKEN_ABI,
      functionName: "balanceOf",
      args: [whitelistBuyer.address],
    });
    console.log(`买家余额: ${buyerBalance} wei`);

    // 1.5. 如果余额不足，项目方转账给用户
    if ((sellerBalance as bigint) < parseEther("1000")) {
      console.log("\n--- 转账Token给卖家 ---");
      const transferHash = await walletClient.writeContract({
        address: ERC20_PERMIT_TOKEN_ADDRESS as `0x${string}`,
        abi: [
          {
            inputs: [
              { internalType: "address", name: "to", type: "address" },
              { internalType: "uint256", name: "amount", type: "uint256" },
            ],
            name: "transfer",
            outputs: [{ internalType: "bool", name: "", type: "bool" }],
            stateMutability: "nonpayable",
            type: "function",
          },
        ],
        functionName: "transfer",
        args: [whitelistUser.address, parseEther("1000")],
        account: projectOwner,
      });
      await publicClient.waitForTransactionReceipt({ hash: transferHash });
      console.log(`Token转账成功，交易哈希: ${transferHash}`);
    }

    if ((buyerBalance as bigint) < parseEther("1000")) {
      console.log("\n--- 转账Token给买家 ---");
      const transferHash = await walletClient.writeContract({
        address: ERC20_PERMIT_TOKEN_ADDRESS as `0x${string}`,
        abi: [
          {
            inputs: [
              { internalType: "address", name: "to", type: "address" },
              { internalType: "uint256", name: "amount", type: "uint256" },
            ],
            name: "transfer",
            outputs: [{ internalType: "bool", name: "", type: "bool" }],
            stateMutability: "nonpayable",
            type: "function",
          },
        ],
        functionName: "transfer",
        args: [whitelistBuyer.address, parseEther("1000")],
        account: projectOwner,
      });
      await publicClient.waitForTransactionReceipt({ hash: transferHash });
      console.log(`Token转账成功，交易哈希: ${transferHash}`);
    }

    // 2. 项目方铸造NFT给白名单用户
    console.log("\n--- 铸造NFT ---");
    const mintHash = await walletClient.writeContract({
      address: PERMIT_NFT_ADDRESS as `0x${string}`,
      abi: PERMIT_NFT_ABI,
      functionName: "mint",
      args: [whitelistUser.address, "ipfs://QmTestNFT"],
      account: projectOwner,
    });
    await publicClient.waitForTransactionReceipt({ hash: mintHash });
    console.log(`NFT铸造成功，交易哈希: ${mintHash}`);

    // 2.5. 验证NFT所有权
    const nftOwner = await publicClient.readContract({
      address: PERMIT_NFT_ADDRESS as `0x${string}`,
      abi: PERMIT_NFT_ABI,
      functionName: "ownerOf",
      args: [BigInt(0)],
    });
    console.log(`NFT铸造成功，所有者: ${nftOwner}`);

    // 3. 白名单用户授权NFT市场合约
    console.log("\n--- 授权NFT市场合约 ---");
    const approveNFTHash = await walletClient.writeContract({
      address: PERMIT_NFT_ADDRESS as `0x${string}`,
      abi: PERMIT_NFT_ABI,
      functionName: "setApprovalForAll",
      args: [NFT_MARKET_PERMIT_ADDRESS as `0x${string}`, true],
      account: whitelistUser,
    });
    await publicClient.waitForTransactionReceipt({ hash: approveNFTHash });
    console.log(`NFT授权成功，交易哈希: ${approveNFTHash}`);

    // 4. 白名单用户上架NFT
    console.log("\n--- 上架NFT ---");
    const listHash = await walletClient.writeContract({
      address: NFT_MARKET_PERMIT_ADDRESS as `0x${string}`,
      abi: NFT_MARKET_PERMIT_ABI,
      functionName: "list",
      args: [BigInt(0), parseEther("100")],
      account: whitelistUser,
    });
    await publicClient.waitForTransactionReceipt({ hash: listHash });
    console.log(`NFT上架成功，交易哈希: ${listHash}`);

    // 5. 检查NFT状态
    const price = await publicClient.readContract({
      address: NFT_MARKET_PERMIT_ADDRESS as `0x${string}`,
      abi: NFT_MARKET_PERMIT_ABI,
      functionName: "prices",
      args: [BigInt(0)],
    });
    console.log(`NFT上架成功，价格: ${price} wei`);

    // 6. 生成permitBuy签名
    console.log("\n--- 生成签名 ---");
    const deadline = BigInt(1753630366); // 使用与Foundry测试相同的deadline
    const signature = await generatePermitSignature(
      whitelistBuyer.address,
      BigInt(0),
      parseEther("100"),
      deadline,
      NFT_MARKET_PERMIT_ADDRESS
    );
    console.log(`签名生成成功`);

    // 7. 买家授权token
    console.log("\n--- 授权Token ---");
    const approveHash = await walletClient.writeContract({
      address: ERC20_PERMIT_TOKEN_ADDRESS as `0x${string}`,
      abi: ERC20_PERMIT_TOKEN_ABI,
      functionName: "approve",
      args: [NFT_MARKET_PERMIT_ADDRESS as `0x${string}`, parseEther("100")],
      account: whitelistBuyer,
    });
    await publicClient.waitForTransactionReceipt({ hash: approveHash });
    console.log(`Token授权成功，交易哈希: ${approveHash}`);

    // 8. 调用permitBuy
    console.log("\n--- 执行permitBuy ---");
    const permitBuyHash = await walletClient.writeContract({
      address: NFT_MARKET_PERMIT_ADDRESS as `0x${string}`,
      abi: NFT_MARKET_PERMIT_ABI,
      functionName: "permitBuy",
      args: [
        BigInt(0),
        parseEther("100"),
        deadline,
        signature.v,
        signature.r,
        signature.s,
      ],
      account: whitelistBuyer,
    });
    await publicClient.waitForTransactionReceipt({ hash: permitBuyHash });
    console.log(`permitBuy执行成功，交易哈希: ${permitBuyHash}`);

    // 9. 验证结果
    console.log("\n--- 验证结果 ---");
    const newOwner = await publicClient.readContract({
      address: PERMIT_NFT_ADDRESS as `0x${string}`,
      abi: PERMIT_NFT_ABI,
      functionName: "ownerOf",
      args: [BigInt(0)],
    });
    console.log(`NFT新所有者: ${newOwner}`);
    console.log(`购买成功: ${newOwner === whitelistBuyer.address}`);

    // 10. 测试非白名单用户（应该失败）
    console.log("\n--- 测试非白名单用户 ---");
    const nonWhitelistUser = privateKeyToAccount(
      "0x1234567890123456789012345678901234567890123456789012345678901234" as `0x${string}`
    );

    try {
      const nonWhitelistSignature = await generatePermitSignature(
        nonWhitelistUser.address,
        BigInt(0),
        parseEther("100"),
        deadline,
        NFT_MARKET_PERMIT_ADDRESS
      );

      await walletClient.writeContract({
        address: NFT_MARKET_PERMIT_ADDRESS as `0x${string}`,
        abi: NFT_MARKET_PERMIT_ABI,
        functionName: "permitBuy",
        args: [
          BigInt(0),
          parseEther("100"),
          deadline,
          nonWhitelistSignature.v,
          nonWhitelistSignature.r,
          nonWhitelistSignature.s,
        ],
        account: nonWhitelistUser,
      });
      console.log("非白名单用户购买成功（不应该发生）");
    } catch (error) {
      console.log("非白名单用户购买失败（符合预期）");
    }

    console.log("\n=== 测试完成 ===");
  } catch (error) {
    console.error("测试失败:", error);
  }
}

// 运行测试
testPermitBuy();
