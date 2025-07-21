## 题目#1

用自己熟悉的语言模拟实现最小的区块链， 包含两个功能：

POW 证明出块，难度为 4 个 0 开头，
每个区块包含previous_hash 让区块串联起来。

如下是一个参考区块结构：
```
block = {
'index': 1,
'timestamp': 1506057125,
'transactions': [
{ 'sender': "xxx",
'recipient': "xxx",
'amount': 5, } ],
'proof': 324984774000,
'previous_hash': "xxxx"
}
```

运行说明：
运行simulation.rs中的test_simulation方法，会创建一条新的区块链，并为其产生两个新的块，以下为控制台打印结果：
```
first block: Block { index: 1, timestamp: 1751981532, transactions: [], proof: 111, previous_hash: "abc" }
second block: Block { index: 2, timestamp: 1751981532, transactions: [Transaction { sender: "aaa", recipient: "bbb", amount: 3 }], proof: 36650, previous_hash: "f19cb77561f4876e2270900380c4fcfc1afa6e43d20f4196f93564c531ea978c" }
new block: Block { index: 3, timestamp: 1751981532, transactions: [Transaction { sender: "aaa", recipient: "bbb", amount: 3 }, Transaction { sender: "ccc", recipient: "ddd", amount: 1 }, Transaction { sender: "eee", recipient: "fff", amount: 2 }], proof: 36865, previous_hash: "3f74d790a1653e2dcbf5d6b017ea1bece4ebcba5ae70434548df1d3ff8d277f9" }
```
