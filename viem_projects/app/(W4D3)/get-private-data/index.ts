import { createPublicClient, http, toHex, keccak256, encodePacked } from "viem";
import { foundry } from "viem/chains";

/*
题目#1 读取合约私有变量数据

使用 Viem 利用 getStorageAt 从链上读取 _locks 数组中的所有元素值，并打印出如下内容：
locks[0]: user:…… ,startTime:……,amount:……
*/

const esRNT_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

const publicClient = createPublicClient({
  chain: foundry,
  transport: http("http://127.0.0.1:8545"),
});

async function testGetPrivateData() {
  console.log("=== 读取合约私有变量数据 测试开始 ===");

  for (let i = 0; i <= 20; i += 2) {
    // _locks 是第一个状态变量，所以它的存储位置是 keccak256(abi.encode(0))
    const arraySlot = keccak256(encodePacked(["uint256"], [BigInt(0)]));
    // 每个数组元素的存储位置是 keccak256(abi.encode(0)) + index
    const slot = BigInt(arraySlot) + BigInt(i);

    // LockInfo: address user (20 bytes) + uint64 startTime (8 bytes) + uint256 amount (32 bytes)
    // 总共 60 bytes，需要读取两个存储槽位

    // 读取第一个存储槽位 (包含 user + startTime + amount 的前4字节)
    const slot1Data = await publicClient.getStorageAt({
      address: esRNT_ADDRESS,
      slot: toHex(slot),
    });

    // 读取第二个存储槽位 (包含 amount 的后28字节)
    const slot2Data = await publicClient.getStorageAt({
      address: esRNT_ADDRESS,
      slot: toHex(slot + BigInt(1)),
    });

    // 检查数据是否存在
    if (!slot1Data || !slot2Data) {
      console.log(`locks[${i}]: 数据读取失败`);
      continue;
    }

    // 解析数据，数据是小端序排列，需要从后往前取值
    // 解析 user 地址 (20 bytes)
    const user = "0x" + slot1Data.slice(26, 66);

    // 解析 startTime (8 bytes)
    const startTime = BigInt("0x" + slot1Data.slice(10, 26));

    // 解析 amount (4 bytes + 28 bytes)
    const amountPart1 = slot1Data.slice(2, 10); // 前 4 bytes 在第一个槽位
    const amountPart2 = slot2Data.slice(10, 66); // 后 28 bytes 在第二个槽位，去掉 0x 前缀，取前28字节
    const amount = BigInt("0x" + amountPart1 + amountPart2); // 组合 amount 的完整数据

    // 格式化输出
    console.log(
      `locks[${i / 2}]: user:${user}, startTime:${startTime}, amount:${amount}`
    );
  }
}

testGetPrivateData();
