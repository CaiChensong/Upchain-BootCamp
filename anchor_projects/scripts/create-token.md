## 题目#1 在 Solana 网络上创建一个 Token

使用 spl-token 在 devnet 测试网创建一个自己昵称的同质化 Token 并使用在控制台查询出自己持有的余额。

提交代码并包含控制台查询截图。

## Answer

1. 设置 devnet 的 RPC 节点

```shell
% solana config set --url "https://devnet.helius-rpc.com/?api-key=e4926d5b-e203-413b-9bf2-fc24e49a238c"

# 运行结果
Config File: /Users/chensongcai/.config/solana/cli/config.yml
RPC URL: https://devnet.helius-rpc.com/?api-key=e4926d5b-e203-413b-9bf2-fc24e49a238c
WebSocket URL: wss://devnet.helius-rpc.com/?api-key=e4926d5b-e203-413b-9bf2-fc24e49a238c (computed)
Keypair Path: /Users/chensongcai/.config/solana/id.json
Commitment: confirmed
```

2. 检查当前账户地址和余额

```shell
% solana address
GHLbEK3o3X2SEmSs9JgP6up7exRn3uzt7RmmEKvHhmiS

% solana balance
5 SOL
```

3. 创建 Token

```shell
% spl-token create-token --enable-metadata --program-2022

# 运行结果
Creating token 7evJxbDiXkgjc5FQAheJAAAFRxUyU7jfYjoCDRPGAmZ under program TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb
To initialize metadata inside the mint, please run `spl-token initialize-metadata 7evJxbDiXkgjc5FQAheJAAAFRxUyU7jfYjoCDRPGAmZ <YOUR_TOKEN_NAME> <YOUR_TOKEN_SYMBOL> <YOUR_TOKEN_URI>`, and sign with the mint authority.

Address:  7evJxbDiXkgjc5FQAheJAAAFRxUyU7jfYjoCDRPGAmZ
Decimals:  9

Signature: 4UHC64o89pMh94Q3rFpHC7rFiWMB9a5M3MscepesB2BWBWdikCF4WacvmWDfV18cezAzPL3PjhnWQ8MVaTGmgtxn
```

4. 初始化 Metadata

```shell
% spl-token initialize-metadata 7evJxbDiXkgjc5FQAheJAAAFRxUyU7jfYjoCDRPGAmZ AerialToken AET -

# 运行结果
Signature: 4TsWbLmMGeX7GceNo9YAqe9duwXJVpKCq1iFTzJCEqso5zcC2JxZFmNbz1cnmZQ3iA3ycdmFozBth5inbHeAWFNG
```

5. 创建 ATA 账户

```shell
% spl-token create-account 7evJxbDiXkgjc5FQAheJAAAFRxUyU7jfYjoCDRPGAmZ

# 运行结果
Creating account EGe2we2LJGycr8kzqVSMfgw6TChJxxKQnn6wx3bLmhvV

Signature: 5bS5HMeGTcgYxXGRKf3oav7LX8bgnQEJ2Qj2VqgJuVgLDspLfWzE2gFZzdGe4vUCXSbGWNpNqYzUrEGPKcei7nQV
```

6. 发行 Token

```shell
% spl-token mint 7evJxbDiXkgjc5FQAheJAAAFRxUyU7jfYjoCDRPGAmZ 100

# 运行结果
Minting 100 tokens
  Token: 7evJxbDiXkgjc5FQAheJAAAFRxUyU7jfYjoCDRPGAmZ
  Recipient: EGe2we2LJGycr8kzqVSMfgw6TChJxxKQnn6wx3bLmhvV

Signature: 45SRdfK3fEnHcqFTmCfWH8ACANi6ZdmPzaCi51MZUQh7oJPiAnYED1xTMnGU6pWdBEiMkzCYr8LU6KnLgPWwZuF5
```

7. 查询余额和相关信息

```shell
% spl-token balance 7evJxbDiXkgjc5FQAheJAAAFRxUyU7jfYjoCDRPGAmZ
100
```

```shell
% spl-token display 7evJxbDiXkgjc5FQAheJAAAFRxUyU7jfYjoCDRPGAmZ

# 运行结果
SPL Token Mint
  Address: 7evJxbDiXkgjc5FQAheJAAAFRxUyU7jfYjoCDRPGAmZ
  Program: TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb
  Supply: 100000000000
  Decimals: 9
  Mint authority: GHLbEK3o3X2SEmSs9JgP6up7exRn3uzt7RmmEKvHhmiS
  Freeze authority: (not set)
Extensions
  Metadata Pointer:
    Authority: GHLbEK3o3X2SEmSs9JgP6up7exRn3uzt7RmmEKvHhmiS
    Metadata address: 7evJxbDiXkgjc5FQAheJAAAFRxUyU7jfYjoCDRPGAmZ
  Metadata:
    Update Authority: GHLbEK3o3X2SEmSs9JgP6up7exRn3uzt7RmmEKvHhmiS
    Mint: 7evJxbDiXkgjc5FQAheJAAAFRxUyU7jfYjoCDRPGAmZ
    Name: AerialToken
    Symbol: AET
    URI: -
```

```shell
% spl-token account-info 7evJxbDiXkgjc5FQAheJAAAFRxUyU7jfYjoCDRPGAmZ

# 运行结果
SPL Token Account
  Address: EGe2we2LJGycr8kzqVSMfgw6TChJxxKQnn6wx3bLmhvV
  Program: TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb
  Balance: 100
  Decimals: 9
  Mint: 7evJxbDiXkgjc5FQAheJAAAFRxUyU7jfYjoCDRPGAmZ
  Owner: GHLbEK3o3X2SEmSs9JgP6up7exRn3uzt7RmmEKvHhmiS
  State: Initialized
  Delegation: (not set)
  Close authority: (not set)
Extensions:
  Immutable owner
```
