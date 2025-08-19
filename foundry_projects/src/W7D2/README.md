## 题目#1 在Dune中创建NFT数据面版

创建 Azuki NFT 代币仪表板，包括：

- 持有者总数
- 持有人名单（持有人，持有的NFT数量）
- 最近一段时间在 OpenSea 的交易量。

提交可以公开访问的Dune看板链接

相关 SQL 语句如下：

```SQL
-- 持有者总数
WITH current_holders AS (
    SELECT 
        "to" as holder,
        ROW_NUMBER() OVER (PARTITION BY tokenId ORDER BY evt_block_time DESC) as rn
    FROM erc721_ethereum.evt_transfer 
    WHERE contract_address = 0xED5AF388653567Af2F388E6224dC7C4b3241C544
)
SELECT 
    COUNT(DISTINCT holder) as current_unique_holders
FROM current_holders 
WHERE rn = 1
    AND holder != 0x0000000000000000000000000000000000000000

-- 持有人名单（持有人，持有的NFT数量）
WITH current_holders AS (
    SELECT 
        "to" as holder,
        tokenId,
        ROW_NUMBER() OVER (PARTITION BY tokenId ORDER BY evt_block_time DESC) as rn
    FROM erc721_ethereum.evt_transfer 
    WHERE contract_address = 0xED5AF388653567Af2F388E6224dC7C4b3241C544
),
holder_counts AS (
    SELECT 
        holder,
        COUNT(*) as nft_count
    FROM current_holders 
    WHERE rn = 1
        AND holder != 0x0000000000000000000000000000000000000000
    GROUP BY holder
)
SELECT 
    holder,
    nft_count
FROM holder_counts
ORDER BY nft_count DESC, holder
LIMIT 100

-- 最近一段时间在 OpenSea 的交易量
SELECT 
    DATE_TRUNC('day', block_time) as trade_date,
    SUM(amount_usd) as daily_volume_usd,
    COUNT(*) as trade_count,
    AVG(amount_usd) as avg_trade_usd,
    MIN(amount_usd) as min_trade_usd,
    MAX(amount_usd) as max_trade_usd
FROM opensea.trades 
WHERE nft_contract_address = 0xED5AF388653567Af2F388E6224dC7C4b3241C544
    AND block_time >= NOW() - interval '30' day
    AND amount_usd > 0
GROUP BY DATE_TRUNC('day', block_time)
ORDER BY trade_date DESC

```

Dune 面板地址：https://dune.com/aerialccc/azuki-nft-dashboard