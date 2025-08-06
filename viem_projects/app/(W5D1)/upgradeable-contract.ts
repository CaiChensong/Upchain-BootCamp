import "dotenv/config";
import {
  createPublicClient,
  createWalletClient,
  http,
  parseEther,
  parseUnits,
  encodePacked,
  keccak256,
} from "viem";
import { privateKeyToAccount, sign } from "viem/accounts";
import { foundry, sepolia } from "viem/chains";
import TOKEN_ABI from "./abi/MyToken.json" with { type: "json" };
import NFT_V1_ABI from "./abi/UpgradeableNFTV1.json" with { type: "json" };
import MARKET_V1_ABI from "./abi/UpgradeableNFTMarketV1.json" with { type: "json" };
import NFT_V2_ABI from "./abi/UpgradeableNFTV2.json" with { type: "json" };
import MARKET_V2_ABI from "./abi/UpgradeableNFTMarketV2.json" with { type: "json" };

/*
使用方法：
1. 设置环境变量:
    export PRIVATE_KEY=your_private_key_here   // admin 账户的私钥，账户中需要有 sepoliaETH， 用于支付gas
    export PRIVATE_KEY_2=your_private_key_here // 买家账户的私钥，账户中需要有 sepoliaETH， 用于支付gas

2. 运行脚本:
    npx tsx app/\(W5D1\)/upgradeable-contract.ts
*/

// const RPC_URL = "http://127.0.0.1:8545";
// const chain = foundry;

const RPC_URL = "https://sepolia.infura.io/v3/53a58eac66a04d69bd2577334f365651";
const chain = sepolia;

// 合约地址
const CONTRACT_ADDRESSES = {
  TOKEN: "0xc044905455dbe3ba560ff064304161b9995b1898",
  NFT_V1_IMPL: "0xBaf737945cb17348C5F603d9F6E618302A5143e0",
  NFT_V2_IMPL: "0x9A895f01782B181f45E3ca7C6BE9Bb5f4e213CFa",
  NFT_PROXY: "0xDad4CbAEEf52420B4e57510097e76badE42301bE",
  MARKET_V1_IMPL: "0xd4783f3eD1C6B832553137597408292Fe4F21636",
  MARKET_V2_IMPL: "0x5d547f9d1ad7E1132B5295E08c1E614e65716f8F",
  MARKET_PROXY: "0x92C5Eb78B93DE6b78e9d24a40bf7e6c34cB199e8",
};

// 账户配置
const ADMIN_ADDRESS = "0x91c035258B5a3B13211A74726d72090734E5BF4a";
const USER_ADDRESS = "0x6E3275F92E2d97A373E8AA4d89EAbe51185792Da";

// 创建客户端
const publicClient = createPublicClient({
  chain,
  transport: http(RPC_URL),
});

const PRIVATE_KEY = process.env.PRIVATE_KEY;
if (!PRIVATE_KEY) {
  throw new Error("未设置 PRIVATE_KEY 环境变量");
}
const account = privateKeyToAccount(PRIVATE_KEY as `0x${string}`);
const walletClient = createWalletClient({
  account,
  chain,
  transport: http(RPC_URL),
});

const PRIVATE_KEY_2 = process.env.PRIVATE_KEY_2;
if (!PRIVATE_KEY_2) {
  throw new Error("未设置 PRIVATE_KEY_2 环境变量");
}
const buyerAccount = privateKeyToAccount(PRIVATE_KEY_2 as `0x${string}`);

const buyerWalletClient = createWalletClient({
  account: buyerAccount,
  chain,
  transport: http(RPC_URL),
});

// 打印合约状态信息
async function printContractStatus() {
  console.log("\n=== 合约状态信息 ===");

  // 打印合约地址
  console.log("合约地址:");
  Object.entries(CONTRACT_ADDRESSES).forEach(([name, address]) => {
    console.log(`  ${name}: ${address}`);
  });

  // 获取 Market 合约的 token 地址
  try {
    const tokenAddress = await publicClient.readContract({
      address: CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
      abi: MARKET_V1_ABI,
      functionName: "token",
    });
    console.log(`Market 合约的 Token 地址: ${tokenAddress}`);
  } catch (error) {
    console.log("无法获取 Market 合约的 Token 地址");
  }

  console.log("\n账户信息:");
  console.log(`管理员地址: ${ADMIN_ADDRESS}`);
  console.log(`用户地址: ${USER_ADDRESS}`);
  console.log(`当前账户: ${account.address}`);
}

// 测试 NFT 铸造功能
async function testNFTMinting() {
  console.log("\n=== 测试 NFT 铸造功能 ===");

  try {
    // 铸造 NFT
    console.log("铸造 NFT Token 0...");
    const hash = await walletClient.writeContract({
      address: CONTRACT_ADDRESSES.NFT_PROXY as `0x${string}`,
      abi: NFT_V1_ABI,
      functionName: "safeMint",
      args: [ADMIN_ADDRESS as `0x${string}`],
    });

    await publicClient.waitForTransactionReceipt({ hash });
    console.log("NFT Token 0 铸造成功");

    // 检查 NFT 所有者
    const owner = await publicClient.readContract({
      address: CONTRACT_ADDRESSES.NFT_PROXY as `0x${string}`,
      abi: NFT_V1_ABI,
      functionName: "ownerOf",
      args: [BigInt(0)],
    });
    console.log(`NFT Token 0 的所有者: ${owner}`);

    return true;
  } catch (error) {
    console.error("NFT 铸造失败:", error);
    return false;
  }
}

// 测试 NFT 授权功能
async function testNFTApproval() {
  console.log("\n=== 测试 NFT 授权功能 ===");

  try {
    // 授权 Market 合约操作 NFT
    console.log("授权 Market 合约操作 NFT...");
    const hash = await walletClient.writeContract({
      address: CONTRACT_ADDRESSES.NFT_PROXY as `0x${string}`,
      abi: NFT_V1_ABI,
      functionName: "setApprovalForAll",
      args: [CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`, true],
    });

    await publicClient.waitForTransactionReceipt({ hash });
    console.log("NFT 授权成功");

    return true;
  } catch (error) {
    console.error("NFT 授权失败:", error);
    return false;
  }
}

// 测试 NFT 上架功能
async function testNFTListing() {
  console.log("\n=== 测试 NFT 上架功能 ===");

  try {
    // 上架 NFT
    const price = parseEther("1"); // 1 ETH
    console.log(`上架 NFT Token 0，价格: ${price} wei`);

    const hash = await walletClient.writeContract({
      address: CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
      abi: MARKET_V1_ABI,
      functionName: "listNFT",
      args: [CONTRACT_ADDRESSES.NFT_PROXY as `0x${string}`, BigInt(1), price],
    });

    await publicClient.waitForTransactionReceipt({ hash });
    console.log("NFT 上架成功");

    // 检查上架状态
    const listing = (await publicClient.readContract({
      address: CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
      abi: MARKET_V1_ABI,
      functionName: "listings",
      args: [BigInt(1)],
    })) as [string, string, bigint, boolean];

    console.log("上架信息:");
    console.log(`  所有者: ${listing[0]}`);
    console.log(`  NFT 合约: ${listing[1]}`);
    console.log(`  价格: ${listing[2]} wei`);
    console.log(`  是否激活: ${listing[3]}`);

    return true;
  } catch (error) {
    console.error("NFT 上架失败:", error);
    return false;
  }
}

// 测试 Token 余额和授权
async function testTokenOperations() {
  console.log("\n=== 测试 Token 操作 ===");

  try {
    // 检查 Token 余额
    const balance = (await publicClient.readContract({
      address: CONTRACT_ADDRESSES.TOKEN as `0x${string}`,
      abi: TOKEN_ABI,
      functionName: "balanceOf",
      args: [account.address],
    })) as bigint;

    console.log(`当前账户 Token 余额: ${balance}`);

    // 检查余额是否足够
    if (balance < parseUnits("1000", 18)) {
      console.log("Token 余额不足，无法进行测试");
      return false;
    }

    // 授权 Market 合约使用 Token
    console.log("授权 Market 合约使用 Token...");
    const approveHash = await walletClient.writeContract({
      address: CONTRACT_ADDRESSES.TOKEN as `0x${string}`,
      abi: TOKEN_ABI,
      functionName: "approve",
      args: [
        CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
        parseUnits("10000", 18),
      ],
    });

    await publicClient.waitForTransactionReceipt({ hash: approveHash });
    console.log("Token 授权成功");

    return true;
  } catch (error) {
    console.error("Token 操作失败:", error);
    return false;
  }
}

// 测试 NFT 购买功能
async function testNFTBuying() {
  console.log("\n=== 测试 NFT 购买功能 ===");

  try {
    // 检查上架状态
    const listing = (await publicClient.readContract({
      address: CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
      abi: MARKET_V1_ABI,
      functionName: "listings",
      args: [BigInt(0)],
    })) as [string, string, bigint, boolean];

    if (!listing[3]) {
      console.log("NFT 未上架，跳过购买测试");
      return false;
    }

    console.log(`当前上架信息:`);
    console.log(`  所有者: ${listing[0]}`);
    console.log(`  价格: ${listing[2]} wei`);

    console.log(`使用账户 ${buyerAccount.address} 购买 NFT`);

    // 首先给购买者一些Token
    console.log("给购买者转账Token...");
    const transferHash = await walletClient.writeContract({
      address: CONTRACT_ADDRESSES.TOKEN as `0x${string}`,
      abi: TOKEN_ABI,
      functionName: "transfer",
      args: [buyerAccount.address, listing[2]],
    });

    await publicClient.waitForTransactionReceipt({ hash: transferHash });
    console.log("Token 转账成功");

    // 购买者授权Market合约使用Token
    console.log("购买者授权Market合约使用Token...");
    const approveHash = await buyerWalletClient.writeContract({
      address: CONTRACT_ADDRESSES.TOKEN as `0x${string}`,
      abi: TOKEN_ABI,
      functionName: "approve",
      args: [CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`, listing[2]],
    });

    await publicClient.waitForTransactionReceipt({ hash: approveHash });
    console.log("购买者Token授权成功");

    // 购买NFT
    console.log(`购买 NFT Token 0，价格: ${listing[2]} wei`);
    const buyHash = await buyerWalletClient.writeContract({
      address: CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
      abi: MARKET_V1_ABI,
      functionName: "buyNFT",
      args: [BigInt(0), listing[2]],
    });

    await publicClient.waitForTransactionReceipt({ hash: buyHash });
    console.log("NFT 购买成功");

    // 检查购买后的状态
    const newOwner = await publicClient.readContract({
      address: CONTRACT_ADDRESSES.NFT_PROXY as `0x${string}`,
      abi: NFT_V1_ABI,
      functionName: "ownerOf",
      args: [BigInt(0)],
    });
    console.log(`购买后 NFT Token 0 的所有者: ${newOwner}`);

    // 检查上架状态是否已清除
    const newListing = (await publicClient.readContract({
      address: CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
      abi: MARKET_V1_ABI,
      functionName: "listings",
      args: [BigInt(0)],
    })) as [string, string, bigint, boolean];

    console.log(`购买后上架状态: ${newListing[3] ? "仍在上架" : "已下架"}`);

    return true;
  } catch (error) {
    console.error("NFT 购买失败:", error);
    return false;
  }
}

// 获取代理管理员地址
async function getProxyAdminAddress(proxyAddress: string): Promise<string> {
  const ADMIN_SLOT =
    "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";

  try {
    const adminAddress = await publicClient.getStorageAt({
      address: proxyAddress as `0x${string}`,
      slot: ADMIN_SLOT,
    });

    if (
      adminAddress &&
      adminAddress !==
        "0x0000000000000000000000000000000000000000000000000000000000000000"
    ) {
      return `0x${adminAddress.slice(26)}`; // 移除前导零，保留地址部分
    }
    throw new Error("无法获取代理管理员地址");
  } catch (error) {
    console.error("获取代理管理员地址失败:", error);
    throw error;
  }
}

// 合约升级功能
async function upgradeContracts() {
  console.log("\n=== 开始合约升级 ===");

  try {
    // 获取 NFT 代理的 ProxyAdmin 地址
    console.log("获取 NFT 代理的 ProxyAdmin 地址...");
    const nftProxyAdminAddress = await getProxyAdminAddress(
      CONTRACT_ADDRESSES.NFT_PROXY
    );
    console.log(`NFT ProxyAdmin 地址: ${nftProxyAdminAddress}`);

    // 获取 Market 代理的 ProxyAdmin 地址
    console.log("获取 Market 代理的 ProxyAdmin 地址...");
    const marketProxyAdminAddress = await getProxyAdminAddress(
      CONTRACT_ADDRESSES.MARKET_PROXY
    );
    console.log(`Market ProxyAdmin 地址: ${marketProxyAdminAddress}`);

    // 升级 NFT 合约到 V2
    console.log("升级 NFT 合约到 V2...");
    const nftUpgradeHash = await walletClient.writeContract({
      address: nftProxyAdminAddress as `0x${string}`,
      abi: [
        {
          inputs: [
            { name: "proxy", type: "address" },
            { name: "implementation", type: "address" },
            { name: "data", type: "bytes" },
          ],
          name: "upgradeAndCall",
          outputs: [],
          stateMutability: "payable",
          type: "function",
        },
      ],
      functionName: "upgradeAndCall",
      args: [
        CONTRACT_ADDRESSES.NFT_PROXY as `0x${string}`,
        CONTRACT_ADDRESSES.NFT_V2_IMPL as `0x${string}`,
        "0x", // 空数据，不执行初始化
      ],
    });

    await publicClient.waitForTransactionReceipt({ hash: nftUpgradeHash });
    console.log("NFT 合约升级成功");

    // 升级 Market 合约到 V2
    console.log("升级 Market 合约到 V2...");
    const marketUpgradeHash = await walletClient.writeContract({
      address: marketProxyAdminAddress as `0x${string}`,
      abi: [
        {
          inputs: [
            { name: "proxy", type: "address" },
            { name: "implementation", type: "address" },
            { name: "data", type: "bytes" },
          ],
          name: "upgradeAndCall",
          outputs: [],
          stateMutability: "payable",
          type: "function",
        },
      ],
      functionName: "upgradeAndCall",
      args: [
        CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
        CONTRACT_ADDRESSES.MARKET_V2_IMPL as `0x${string}`,
        "0x", // 空数据，不执行初始化
      ],
    });

    await publicClient.waitForTransactionReceipt({ hash: marketUpgradeHash });
    console.log("Market 合约升级成功");

    return true;
  } catch (error) {
    console.error("合约升级失败:", error);
    console.log("升级失败，请检查:");
    console.log("1. 代理管理员权限是否正确");
    console.log("2. 新实现合约是否已部署");
    console.log("3. 代理合约地址是否正确");
    return false;
  }
}

// 测试 NFT V2 合约的新功能
async function testNFTV2Features() {
  console.log("\n=== 测试 NFT V2 合约新功能 ===");

  try {
    // 初始化 V2 合约
    console.log("初始化 NFT V2 合约...");
    const initHash = await walletClient.writeContract({
      address: CONTRACT_ADDRESSES.NFT_PROXY as `0x${string}`,
      abi: NFT_V2_ABI,
      functionName: "initializeV2",
      args: [],
    });

    await publicClient.waitForTransactionReceipt({ hash: initHash });
    console.log("NFT V2 初始化成功");

    // 获取版本信息
    const version = await publicClient.readContract({
      address: CONTRACT_ADDRESSES.NFT_PROXY as `0x${string}`,
      abi: NFT_V2_ABI,
      functionName: "getVersion",
      args: [],
    });
    console.log(`NFT 合约版本: ${version}`);

    // 设置新版本
    console.log("设置新版本...");
    const setVersionHash = await walletClient.writeContract({
      address: CONTRACT_ADDRESSES.NFT_PROXY as `0x${string}`,
      abi: NFT_V2_ABI,
      functionName: "setVersion",
      args: ["2.1.0"],
    });

    await publicClient.waitForTransactionReceipt({ hash: setVersionHash });
    console.log("版本设置成功");

    // 验证新版本
    const newVersion = await publicClient.readContract({
      address: CONTRACT_ADDRESSES.NFT_PROXY as `0x${string}`,
      abi: NFT_V2_ABI,
      functionName: "getVersion",
      args: [],
    });
    console.log(`更新后的版本: ${newVersion}`);

    return true;
  } catch (error) {
    console.error("NFT V2 功能测试失败:", error);
    return false;
  }
}

// 生成签名上架所需的签名
async function generateListingSignature(
  nftToken: string,
  tokenId: bigint,
  price: bigint,
  deadline: bigint
): Promise<string> {
  try {
    // 获取 Market 合约的当前 nonce
    const nonce = (await publicClient.readContract({
      address: CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
      abi: MARKET_V2_ABI,
      functionName: "getNonce",
      args: [],
    })) as bigint;

    console.log(`当前 nonce: ${nonce}`);

    // 构造消息哈希
    // 根据合约中的签名验证逻辑：
    // keccak256(abi.encodePacked(address(this), _nftToken, _tokenId, _price, _nonce, _deadline))
    const messageHash = keccak256(
      encodePacked(
        ["address", "address", "uint256", "uint256", "uint256", "uint256"],
        [
          CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
          nftToken as `0x${string}`,
          tokenId,
          price,
          nonce,
          deadline,
        ]
      )
    );

    console.log(`消息哈希: ${messageHash}`);

    // 签名消息 - 使用本地账户签名
    const signature = await account.signMessage({
      message: { raw: messageHash },
    });

    console.log(`生成的签名: ${signature}`);
    return signature;
  } catch (error) {
    console.error("生成签名失败:", error);
    throw error;
  }
}

// 测试签名上架功能
async function testSignatureListing() {
  console.log("\n=== 测试签名上架功能 ===");

  try {
    // 设置上架参数
    const nftToken = CONTRACT_ADDRESSES.NFT_PROXY;
    const tokenId = BigInt(2);
    const price = parseEther("2"); // 2 ETH
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1小时后过期

    // 检查NFT所有者
    const nftOwner = await publicClient.readContract({
      address: CONTRACT_ADDRESSES.NFT_PROXY as `0x${string}`,
      abi: NFT_V2_ABI,
      functionName: "ownerOf",
      args: [tokenId],
    });
    console.log(`NFT Token ${tokenId} 的所有者: ${nftOwner}`);
    console.log(`当前账户: ${account.address}`);

    console.log(`上架参数:`);
    console.log(`  NFT 合约: ${nftToken}`);
    console.log(`  Token ID: ${tokenId}`);
    console.log(`  价格: ${price} wei`);
    console.log(`  过期时间: ${deadline}`);

    // 生成签名
    console.log("生成签名...");
    const signature = await generateListingSignature(
      nftToken,
      tokenId,
      price,
      deadline
    );

    // 使用签名上架 NFT
    console.log("使用签名上架 NFT...");
    const listHash = await walletClient.writeContract({
      address: CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
      abi: MARKET_V2_ABI,
      functionName: "listWithSignature",
      args: [
        nftToken as `0x${string}`,
        tokenId,
        price,
        deadline,
        signature as `0x${string}`,
      ],
    });

    await publicClient.waitForTransactionReceipt({ hash: listHash });
    console.log("签名上架成功");

    // 验证上架状态
    const listing = (await publicClient.readContract({
      address: CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
      abi: MARKET_V2_ABI,
      functionName: "listings",
      args: [tokenId],
    })) as [string, string, bigint, boolean];

    console.log("上架验证:");
    console.log(`  所有者: ${listing[0]}`);
    console.log(`  NFT 合约: ${listing[1]}`);
    console.log(`  价格: ${listing[2]} wei`);
    console.log(`  是否激活: ${listing[3]}`);

    return true;
  } catch (error) {
    console.error("签名上架测试失败:", error);
    return false;
  }
}

// 测试 Market V2 合约的新功能
async function testMarketV2Features() {
  console.log("\n=== 测试 Market V2 合约新功能 ===");

  try {
    // 初始化 V2 合约
    console.log("初始化 Market V2 合约...");
    const initHash = await walletClient.writeContract({
      address: CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
      abi: MARKET_V2_ABI,
      functionName: "initializeV2",
      args: [],
    });

    await publicClient.waitForTransactionReceipt({ hash: initHash });
    console.log("Market V2 初始化成功");

    // 铸造一个新的 NFT 用于测试签名上架
    console.log("铸造新的 NFT Token 2 用于测试...");
    const mintHash = await walletClient.writeContract({
      address: CONTRACT_ADDRESSES.NFT_PROXY as `0x${string}`,
      abi: NFT_V2_ABI,
      functionName: "safeMint",
      args: [account.address],
    });

    await publicClient.waitForTransactionReceipt({ hash: mintHash });
    console.log("NFT Token 2 铸造成功");

    // 测试签名上架功能
    const signatureSuccess = await testSignatureListing();
    if (!signatureSuccess) {
      console.log("签名上架功能测试失败");
    }
    return true;
  } catch (error) {
    console.error("Market V2 功能测试失败:", error);
    return false;
  }
}

// 打印升级后的合约状态
async function printUpgradedContractStatus() {
  console.log("\n=== 升级后的合约状态信息 ===");

  // 打印合约地址
  console.log("合约地址:");
  Object.entries(CONTRACT_ADDRESSES).forEach(([name, address]) => {
    console.log(`  ${name}: ${address}`);
  });

  // 获取 Market 合约的 token 地址
  try {
    const tokenAddress = await publicClient.readContract({
      address: CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
      abi: MARKET_V2_ABI,
      functionName: "token",
    });
    console.log(`Market 合约的 Token 地址: ${tokenAddress}`);
  } catch (error) {
    console.log("无法获取 Market 合约的 Token 地址");
  }

  // 获取 NFT 合约版本
  try {
    const nftVersion = await publicClient.readContract({
      address: CONTRACT_ADDRESSES.NFT_PROXY as `0x${string}`,
      abi: NFT_V2_ABI,
      functionName: "getVersion",
      args: [],
    });
    console.log(`NFT 合约版本: ${nftVersion}`);
  } catch (error) {
    console.log("无法获取 NFT 合约版本");
  }

  // 获取 Market 合约 nonce
  try {
    const marketNonce = await publicClient.readContract({
      address: CONTRACT_ADDRESSES.MARKET_PROXY as `0x${string}`,
      abi: MARKET_V2_ABI,
      functionName: "getNonce",
      args: [],
    });
    console.log(`Market 合约 nonce: ${marketNonce}`);
  } catch (error) {
    console.log("无法获取 Market 合约 nonce");
  }

  console.log("\n账户信息:");
  console.log(`管理员地址: ${ADMIN_ADDRESS}`);
  console.log(`用户地址: ${USER_ADDRESS}`);
  console.log(`当前账户: ${account.address}`);
}

// 主测试函数
async function testUpgradeableNFTMarket() {
  console.log("开始测试 UpgradeableNFTMarketV1 合约...");

  // 打印合约状态
  await printContractStatus();

  // 测试 NFT 铸造
  const mintSuccess = await testNFTMinting();
  if (!mintSuccess) {
    console.log("NFT 铸造失败，停止测试");
    return;
  }

  // 测试 NFT 授权
  const approvalSuccess = await testNFTApproval();
  if (!approvalSuccess) {
    console.log("NFT 授权失败，停止测试");
    return;
  }

  // 测试 Token 操作
  const tokenSuccess = await testTokenOperations();
  if (!tokenSuccess) {
    console.log("Token 操作失败，停止测试");
    return;
  }

  // 测试 NFT 上架
  const listingSuccess = await testNFTListing();
  if (!listingSuccess) {
    console.log("NFT 上架失败，停止测试");
    return;
  }

  // 测试 NFT 购买
  await testNFTBuying();

  console.log("\n=== V1 合约测试完成 ===");

  // 开始升级测试
  console.log("\n开始合约升级测试...");

  // 升级合约
  const upgradeSuccess = await upgradeContracts();
  if (!upgradeSuccess) {
    console.log("合约升级失败，停止测试");
    return;
  }

  // 打印升级后的状态
  await printUpgradedContractStatus();

  // 测试 NFT V2 新功能
  const nftV2Success = await testNFTV2Features();
  if (!nftV2Success) {
    console.log("NFT V2 功能测试失败");
  }

  // 测试 Market V2 新功能
  const marketV2Success = await testMarketV2Features();
  if (!marketV2Success) {
    console.log("Market V2 功能测试失败");
  }

  console.log("\n=== 升级测试完成 ===");
}

// 运行测试
testUpgradeableNFTMarket().catch(console.error);
