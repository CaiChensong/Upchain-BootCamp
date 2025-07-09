## Gas 手续费 - EIP1559 之后

- 用户手续费预算设置：gas limit 、max fee 、max tips fee
- 用户手续费用 = gas used (<gas limit) * (base fee + tips fee)
- 燃烧掉 = base fee * gas used
- 矿工收益 = tips fee * gas used
- tips fee = min(max fee - base fee, max tips fee)


## 相关计算

### 题目#1
在以太坊上，用户发起一笔交易，设置了
    GasLimit 为 10000
    Max Fee 为 10 GWei
    Max priority fee 为 1 GWei
为此用户应该在钱包账号里多少 GWei 的余额？
```
gas used max = gas limit = 10000
(base fee + tips fee) max = max fee = 10 Gwei
手续费用 max = gas used max * max(base fee + tips fee) = 10000 * 10 Gwei = 100,000 Gwei
```

### 题目#2
在以太坊上，用户发起一笔交易，设置了 
    GasLimit 为 10000, 
    Max Fee 为 10 GWei, 
    Max priority Fee 为 1 GWei，
在打包时，Base Fee 为 5 GWei, 实际消耗的Gas为 5000， 那么矿工（验证者）拿到的手续费是多少 GWei ?
```
tips fee = min(max fee - base fee, max tips fee) = min(10-5, 1) = 1 Gwei
矿工收益 = tips fee * gas used = 1 * 5000 = 5000 Gwei
```

### 题目#3
在以太坊上，用户发起一笔交易，设置了 
    GasLimit 为 10000, 
    Max Fee 为 10 GWei, 
    Max priority Fee 为 1 GWei，
在打包时，Base Fee 为 5 GWei, 实际消耗的Gas为 5000， 那么用户需要支付的的手续费是多少 GWei ?
```
tips fee = min(max fee - base fee, max tips fee) = min(10 - 5, 1) = 1 Gwei
总手续费 = gas used * (base fee + tips fee) = 5000 * (5 + 1) = 30,000 Gwei
```

### 题目#4
在以太坊上，用户发起一笔交易，设置了 
    GasLimit 为 10000, 
    Max Fee 为 10 GWei, 
    Max priority Fee 为 1 GWei，
在打包时，Base Fee 为 5 GWei, 实际消耗的 Gas 为 5000， 那么燃烧掉的 Eth 数量是多少 GWei ?
```
燃烧掉 = base fee * gas used = 5000 * 5 = 25,000 GWei
```

