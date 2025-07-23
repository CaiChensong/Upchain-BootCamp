"use client";

/*
题目#2 
使⽤ Viem.sh 监听 NFTMarket 的买卖记录

在 NFTMarket 合约中在上架（list）和买卖函数（buyNFT、tokensReceived）中添加相应事件，在后台监听上架和买卖事件，如果链上发生了上架或买卖行为，打印出相应的日志。

请提交 github 代码
*/

import { useEffect } from "react";
import { createPublicClient, http, publicActions } from "viem";
import NFTMARKET_ABI from "./abi/MyNFTMarket.json" with { type: "json" };
import { foundry } from "viem/chains";

const NFTMARKET_ADDRESS = "0x959922be3caee4b8cd9a407cc3ac1c251c2007b1";
const RPC_URL = "http://127.0.0.1:8545";

export default function NFTMarketListener() {
  useEffect(() => {
    const publicClient = createPublicClient({
      chain: foundry,
      transport: http(RPC_URL),
    }).extend(publicActions);

    publicClient.watchContractEvent({
      address: NFTMARKET_ADDRESS,
      abi: NFTMARKET_ABI,
      eventName: "NFTListed",
      onLogs: (logs) => {
        logs.forEach((log: any) => {
          console.log(
            `NFT上架: 卖家: ${log.args.seller}, tokenId: ${log.args.tokenId}, 价格: ${log.args.price}`
          );
        });
      },
    });

    publicClient.watchContractEvent({
      address: NFTMARKET_ADDRESS,
      abi: NFTMARKET_ABI,
      eventName: "NFTBought",
      onLogs: (logs) => {
        logs.forEach((log: any) => {
          console.log(
            `NFT买卖: 买家: ${log.args.buyer}, tokenId: ${log.args.tokenId}, 价格: ${log.args.price}`
          );
        });
      },
    });
  }, []);

  return null;
}
