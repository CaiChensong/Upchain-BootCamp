import { createAppKit } from "@reown/appkit/react";
import { WagmiProvider } from "wagmi";
import { optimism, mainnet, foundry } from "@reown/appkit/networks";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiAdapter } from "@reown/appkit-adapter-wagmi";

// 0. Setup queryClient
const queryClient = new QueryClient();

// 1. Get projectId from https://cloud.reown.com
const projectId = "ebd23f3796f84e9c7cd73c16a966f990";

// 2. 元数据在在钱包连接界面中显示 - Wallet Connect 扫码时将看到此信息
const metadata = {
  name: "NFT Market Demo",
  description: "Aerial NFT Market Demo Project",
  url: "https://reown.com/appkit",
  icons: ["../../public/favicon.ico"],
};

// 3. Set the networks
// const foundry = {
//   id: 31337,
//   name: "Foundry",
//   nativeCurrency: {
//     decimals: 18,
//     name: "Ether",
//     symbol: "ETH",
//   },
//   rpcUrls: {
//     default: {
//       http: ["https://famous-donkeys-arrive.loca.lt"],
//       webSocket: ["ws://127.0.0.1:8545"],
//     },
//   },
// };

const networks = [foundry, optimism, mainnet] as [
  typeof foundry,
  typeof optimism,
  typeof mainnet,
];

// 4. Create Wagmi Adapter
const wagmiAdapter = new WagmiAdapter({
  networks,
  projectId,
  ssr: true,
});

// 5. 钱包连接模态框， 在调用 useAppKit 的 open 函数时显示
createAppKit({
  adapters: [wagmiAdapter], // 与 wagmi 框架集成，负责处理底层的钱包连接、网络切换等操作
  networks,
  projectId,
  metadata,
  features: {
    analytics: true,
  },
});

export function AppKitProvider({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={wagmiAdapter.wagmiConfig}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </WagmiProvider>
  );
}
