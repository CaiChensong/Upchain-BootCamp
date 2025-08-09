// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1 实现一个 LaunchPad 平台

修改之前的 最小代理工厂（foundry_projects/src/W4D2/MemeFactory.sol）
- 1% 费用修改为 5%
- 5% 的 ETH 与相应的 Token 调用 Uniswap V2Router AddLiquidity 添加 MyToken 与 ETH 的流动性（如果是第一次添加流动性按 mint 价格作为流动性价格）。
- 除了之前的 mintMeme() 可以购买 meme 外，添加一个方法: buyMeme()，以便在 Uniswap 的价格优于设定的起始价格时，用户可调用该函数来购买 Meme。

需要包含你的测试用例，运行 Case 的日志，请贴出你的 github 代码。

梳理需求：
项目方收取的 5% 费用都用于添加流动性，95% 给 Meme 发行者
发行者拿到所有的meme token
额外mint对应数量的meme token用于添加流动性

*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "uniswap-v2/v2-periphery/interfaces/IUniswapV2Router02.sol";

contract MemeLaunchPad is Ownable {
    uint256 public immutable PROJECT_FEE_PERCENTAGE = 5; // 5% 手续费，用于添加流动性

    address public baseMeme; // Meme代币模板合约地址
    address public uniswapRouter; // Uniswap V2 Router地址

    mapping(address => bool) public isMeme; // 记录是否为平台部署的Meme代币
    mapping(address => bool) public isLiquidityAdded; // 记录是否已添加流动性

    event MemeDeployed(
        address indexed memeAddress, string symbol, uint256 totalSupply, uint256 perMint, uint256 price, address creator
    );
    event MemeMinted(address indexed memeAddress, address indexed to, uint256 amount);
    event LiquidityAdded(address indexed memeAddress, uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    event MemeBought(address indexed memeAddress, address indexed to, uint256 amount, uint256 price);

    constructor(address _projectOwner, address _uniswapRouter) Ownable(_projectOwner) {
        require(_projectOwner != address(0), "MemeFactory: Project owner must be set");
        require(_uniswapRouter != address(0), "MemeFactory: Uniswap router must be set");

        uniswapRouter = _uniswapRouter;

        baseMeme = address(new MemeToken());
    }

    // 部署新的Meme代币
    function deployMeme(string memory symbol, uint256 totalSupply, uint256 perMint, uint256 price) public {
        require(totalSupply > 0, "MemeFactory: Total supply must be greater than 0");
        require(perMint > 0, "MemeFactory: Per mint must be greater than 0");
        require(perMint <= totalSupply, "MemeFactory: Per mint must be less than or equal to total supply");

        address meme = Clones.clone(address(baseMeme));
        MemeToken(meme).initialize(symbol, totalSupply, perMint, price, msg.sender);
        isMeme[meme] = true;

        emit MemeDeployed(meme, symbol, totalSupply, perMint, price, msg.sender);
    }

    // 铸造Meme代币（按固定价格购买）
    function mintMeme(address tokenAddr) public payable {
        require(isMeme[tokenAddr], "MemeFactory: Token is not deployed");

        MemeToken memeToken = MemeToken(tokenAddr);
        uint256 perMintPrice = memeToken.price() * memeToken.perMint();
        require(msg.value >= perMintPrice, "MemeFactory: Insufficient payment");

        uint256 liquidityFee = (perMintPrice * PROJECT_FEE_PERCENTAGE) / 100; // 5% 用于添加流动性
        uint256 creatorFee = perMintPrice - liquidityFee; // 95% 给Meme发行者

        // 分配费用：5%用于添加流动性，95%给Meme发行者
        (bool creatorSuccess,) = payable(memeToken.creator()).call{value: creatorFee}("");
        require(creatorSuccess, "MemeFactory: Failed to transfer creator fee");

        // 铸造代币给用户（发行者拿到所有的meme token）
        memeToken.mint(msg.sender);

        // 计算用于添加流动性对应数量的meme token
        uint256 liquidityTokenAmount = liquidityFee / memeToken.price();

        // 添加流动性
        _addLiquidity(tokenAddr, liquidityFee, liquidityTokenAmount);

        if (msg.value > perMintPrice) {
            (bool refundSuccess,) = payable(msg.sender).call{value: msg.value - perMintPrice}("");
            require(refundSuccess, "MemeFactory: Failed to refund");
        }

        emit MemeMinted(tokenAddr, msg.sender, memeToken.perMint());
    }

    // 内部方法：添加流动性到Uniswap
    function _addLiquidity(address tokenAddr, uint256 ethAmount, uint256 tokenAmount) internal {
        if (isLiquidityAdded[tokenAddr]) {
            return; // 已经添加过流动性
        }

        // 为流动性铸造指定数量的代币到合约地址
        MemeToken(tokenAddr).mintToAddLiquidity(address(this), tokenAmount);

        // 批准Router使用代币
        MemeToken(tokenAddr).approve(uniswapRouter, tokenAmount);

        // 添加流动性
        try IUniswapV2Router02(uniswapRouter).addLiquidityETH{value: ethAmount}(
            tokenAddr,
            tokenAmount,
            0, // amountTokenMin
            0, // amountETHMin
            address(this), // to
            block.timestamp + 300 // deadline
        ) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
            isLiquidityAdded[tokenAddr] = true;
            emit LiquidityAdded(tokenAddr, amountToken, amountETH, liquidity);
        } catch {
            // 如果添加流动性失败，将ETH退还给项目方
            (bool success,) = payable(owner()).call{value: ethAmount}("");
            require(success, "MemeFactory: Failed to refund liquidity fee");
        }
    }

    // 通过Uniswap购买Meme代币（当Uniswap价格更优时）
    function buyMeme(address tokenAddr) public payable {
        require(isMeme[tokenAddr], "MemeFactory: Token is not deployed");
        require(msg.value > 0, "MemeFactory: Must send ETH to buy tokens");

        uint256 uniswapPrice = getUniswapPrice(tokenAddr);
        uint256 mintPrice = MemeToken(tokenAddr).price();

        require(uniswapPrice < mintPrice, "MemeFactory: Uniswap price not better than mint price");

        // 创建交易路径：ETH -> WETH -> Token
        address[] memory path = new address[](2);
        path[0] = IUniswapV2Router02(uniswapRouter).WETH(); // 使用router获取WETH地址
        path[1] = tokenAddr;

        // 计算最小输出代币数量（允许1%滑点）
        uint256[] memory expectedAmounts = IUniswapV2Router02(uniswapRouter).getAmountsOut(msg.value, path);
        uint256 minTokenAmount = expectedAmounts[1] * 99 / 100;

        // 从Uniswap购买代币
        try IUniswapV2Router02(uniswapRouter).swapExactETHForTokens{value: msg.value}(
            minTokenAmount, path, msg.sender, block.timestamp + 300
        ) returns (uint256[] memory amounts) {
            emit MemeBought(tokenAddr, msg.sender, amounts[1], uniswapPrice);
        } catch {
            revert("MemeFactory: Swap failed");
        }
    }

    // 获取Uniswap上的代币价格（以ETH计价）
    function getUniswapPrice(address tokenAddr) public view returns (uint256) {
        // 创建交易路径：WETH -> Token
        address[] memory path = new address[](2);
        path[0] = IUniswapV2Router02(uniswapRouter).WETH();
        path[1] = tokenAddr;

        try IUniswapV2Router02(uniswapRouter).getAmountsOut(1e18, path) returns (uint256[] memory amounts) {
            // amounts[1] 是用1 ETH能够兑换到的代币数量
            return amounts[1];
        } catch {
            // 如果获取失败，说明没有流动性或路径不存在
            return type(uint256).max;
        }
    }

    function updateProjectOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "MemeFactory: New owner can not be zero address");
        _transferOwnership(newOwner);
    }

    function updateUniswapRouter(address newRouter) public onlyOwner {
        require(newRouter != address(0), "MemeFactory: New router can not be zero address");
        uniswapRouter = newRouter;
    }

    // 允许合约接收ETH
    receive() external payable {}
}

contract MemeToken is ERC20 {
    string public memeSymbol;
    uint256 public memeTotalSupply;

    uint256 public perMint;
    uint256 public mintedAmount;
    uint256 public price;

    address public creator;
    address public factory;

    constructor() ERC20("MemeToken", "") {}

    function initialize(string memory _symbol, uint256 _totalSupply, uint256 _perMint, uint256 _price, address _creator)
        public
    {
        require(creator == address(0), "MemeToken: Already initialized");
        require(_totalSupply > 0, "MemeToken: Total supply must be greater than 0");
        require(_perMint > 0, "MemeToken: Per mint must be greater than 0");
        require(_perMint <= _totalSupply, "MemeToken: Per mint must be less than or equal to total supply");

        memeSymbol = _symbol;
        memeTotalSupply = _totalSupply;
        perMint = _perMint;
        price = _price;
        creator = _creator;

        factory = msg.sender;
        mintedAmount = 0;
    }

    function mint(address to) public {
        require(msg.sender == factory, "MemeToken: Only MemeFactory can mint");
        require(mintedAmount + perMint <= memeTotalSupply, "MemeToken: Minted amount exceeds total supply");

        mintedAmount += perMint;
        _mint(to, perMint);
    }

    // 专门用于流动性的铸造方法，可以指定铸造数量
    function mintToAddLiquidity(address to, uint256 amount) public {
        require(msg.sender == factory, "MemeToken: Only MemeFactory can mint");
        require(amount > 0, "MemeToken: Amount must be greater than 0");
        require(mintedAmount + amount <= memeTotalSupply, "MemeToken: Minted amount exceeds total supply");

        mintedAmount += amount;
        _mint(to, amount);
    }
}
