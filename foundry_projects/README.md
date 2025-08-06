## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript \
    --rpc-url $LOCAL_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    -vvvv
```

### Get ABI Json

```shell
forge inspect src/Counter.sol:Counter abi --json > Counter.json


forge inspect lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy abi --json > TransparentUpgradeableProxy.json

```

### Remapping

```shell
forge remappings > remappings.txt
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## 在 Sepolia 测试网上部署过的合约：

ERC20 Token 合约

- 代码：foundry_projects/src/W2D4/MyToken.sol
- 地址：https://sepolia.etherscan.io/address/0xc044905455dbe3ba560ff064304161b9995b1898

Bank 合约

- 代码：foundry_projects/src/W1D3/Bank.sol
- 地址：https://sepolia.etherscan.io/address/0x57cca9d3c62f1b5451412139f8da210fc209a24c

TokenBank 合约

- 代码：foundry_projects/src/W4D5/TokenBank.sol
- 地址：https://sepolia.etherscan.io/address/0xDbDDe79DB33e72741A52100f08B12D3603818318

Delegate 合约

- 代码：foundry_projects/src/W4D5/Delegate.sol
- 地址：https://sepolia.etherscan.io/address/0xf6681aea44c1fdd66b49ef1f44a0bd2b38c242ce

UpgradeableNFTV1 合约

- 代码：foundry_projects/src/W5D1/UpgradeableNFT.sol
- 地址：https://sepolia.etherscan.io/address/0xBaf737945cb17348C5F603d9F6E618302A5143e0

UpgradeableNFTV2 合约

- 代码：foundry_projects/src/W5D1/UpgradeableNFT.sol
- 地址：https://sepolia.etherscan.io/address/0x9A895f01782B181f45E3ca7C6BE9Bb5f4e213CFa

UpgradeableNFT 代理合约

- 代码：foundry_projects/lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol
- 地址：https://sepolia.etherscan.io/address/0xDad4CbAEEf52420B4e57510097e76badE42301bE

UpgradeableNFTMarketV1 合约

- 代码：foundry_projects/src/W5D1/UpgradeableNFTMarket.sol
- 地址：https://sepolia.etherscan.io/address/0xd4783f3eD1C6B832553137597408292Fe4F21636

UpgradeableNFTMarketV2 合约

- 代码：foundry_projects/src/W5D1/UpgradeableNFTMarket.sol
- 地址：https://sepolia.etherscan.io/address/0x5d547f9d1ad7E1132B5295E08c1E614e65716f8F

UpgradeableNFTMarket 代理合约

- 代码：foundry_projects/lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol
- 地址：https://sepolia.etherscan.io/address/0x92C5Eb78B93DE6b78e9d24a40bf7e6c34cB199e8
