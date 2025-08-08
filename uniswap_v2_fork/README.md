## Uniswap V2 Fork

题目#1 Uniswap V2 源代码分析与部署

创建一个 Foundry 工程，添加 Uniswap V2 核心及周边代码：

- 阅读并分析 Uniswap V2 源代码，并为主要合约添加代码注释
- （可选）发布一篇文章阐述自己对 Uniswap 理解的文章，如代码解读等，积累自己的个人 IP
- 在本地部署 Uniswap V2 核心及周边源代码 （注意：你需要 周边代码库 pairFor 方法中出现的 init_code_hash ）

请贴出的 github 代码及文章链接（如果写了文章的话）

## Answer

本项目 fork 了 Uniswap V2 相关的智能合约代码，修复了相关的编译错误和 init code hash 的问题。相关文档：

- 部署相关：[README.md](./script/README.md)
- 代码分析（使用 AI 辅助生成）：[UniswapV2_Analysis.md](./UniswapV2_Analysis.md)
