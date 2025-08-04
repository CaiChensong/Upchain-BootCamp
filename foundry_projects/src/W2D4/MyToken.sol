// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
将下方合约部署到 https://sepolia.etherscan.io/ ，要求如下：

- 使用在 Decert.me 登录的钱包来部署合约
- 贴出编写 forge script 的脚本合约
- 并给出部署后的合约链接地址
- 将合约在 https://sepolia.etherscan.io/ 中开源，要求给出对应的合约链接。


### 部署命令
```shell
forge script script/MyToken.s.sol --private-key $PRIVATE_KEY --rpc-url sepolia --broadcast
```

### 开源验证命令
```shell
forge verify-contract 0xC044905455DBe3ba560FF064304161b9995B1898 src/MyToken.sol:MyToken \
    --constructor-args $(cast abi-encode "constructor(string,string)" "MyToken" "MTK") \
    --verifier etherscan \
    --verifier-url https://api-sepolia.etherscan.io/api \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain-id 11155111
```

### 合约地址：https://sepolia.etherscan.io/address/0xc044905455dbe3ba560ff064304161b9995b1898
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(msg.sender, 1e10 * 1e18);
    }
}
