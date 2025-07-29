// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1 用最小代理实现 ERC20 铸币工厂

假设你（项目方）正在 EVM 链上创建一个 Meme 发射平台，每一个 MEME 都是一个 ERC20 token ，
你需要编写一个通过最⼩代理方式来创建 Meme 的⼯⼚合约，以减少 Meme 发行者的 Gas 成本，编写的⼯⼚合约包含两个方法：

- deployMeme(string symbol, uint totalSupply, uint perMint, uint price), Meme 发行者调⽤该⽅法创建 ERC20 合约（实例）, 参数描述如下： 
  - symbol 表示新创建代币的代号（ ERC20 代币名字可以使用固定的），
  - totalSupply 表示总发行量，
  - perMint 表示一次铸造 Meme 的数量（为了公平的铸造，而不是一次性所有的 Meme 都铸造完），
  - price 表示每个 Meme 铸造时需要的支付的费用（wei 计价）。
  - 每次铸造费用分为两部分，一部分（1%）给到项目方（你），一部分给到 Meme 的发行者（即调用该方法的用户）。

- mintMeme(address tokenAddr) payable: 购买 Meme 的用户每次调用该函数时，会发行 deployMeme 确定的 perMint 数量的 token，并收取相应的费用。

要求：

- 包含测试用例（需要有完整的 forge 工程）：
  - 费用按比例正确分配到 Meme 发行者账号及项目方账号。
  - 每次发行的数量正确，且不会超过 totalSupply。
- 请包含运行测试的截图或日志。
- 请贴出你的代码工程链接。
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract MemeFactory {
    uint256 public immutable PROJECT_FEE_PERCENTAGE = 1; // 1%

    address public projectOwner;
    address public baseMeme;

    mapping(address => bool) public isMeme;

    event MemeDeployed(
        address indexed memeAddress, string symbol, uint256 totalSupply, uint256 perMint, uint256 price, address creator
    );
    event MemeMinted(address indexed memeAddress, address indexed to, uint256 amount);

    constructor(address _projectOwner) {
        require(_projectOwner != address(0), "MemeFactory: Project owner must be set");
        projectOwner = _projectOwner;

        baseMeme = address(new Meme());
    }

    function deployMeme(string memory symbol, uint256 totalSupply, uint256 perMint, uint256 price) public {
        require(totalSupply > 0, "MemeFactory: Total supply must be greater than 0");
        require(perMint > 0, "MemeFactory: Per mint must be greater than 0");
        require(perMint <= totalSupply, "MemeFactory: Per mint must be less than or equal to total supply");

        address meme = Clones.clone(address(baseMeme));
        Meme(meme).initialize(symbol, totalSupply, perMint, price, msg.sender);
        isMeme[meme] = true;

        emit MemeDeployed(meme, symbol, totalSupply, perMint, price, msg.sender);
    }

    function mintMeme(address tokenAddr) public payable {
        require(isMeme[tokenAddr], "MemeFactory: Token is not deployed");

        Meme memeToken = Meme(tokenAddr);
        uint256 perMintPrice = memeToken.price() * memeToken.perMint();
        require(msg.value >= perMintPrice, "MemeFactory: Insufficient payment");

        uint256 projectFee = (perMintPrice * PROJECT_FEE_PERCENTAGE) / 100;
        uint256 creatorFee = perMintPrice - projectFee;

        // 分配费用：1%给项目方，99%给Meme发行者
        (bool projectSuccess,) = payable(projectOwner).call{value: projectFee}("");
        require(projectSuccess, "MemeFactory: Failed to transfer project fee");

        (bool creatorSuccess,) = payable(memeToken.creator()).call{value: creatorFee}("");
        require(creatorSuccess, "MemeFactory: Failed to transfer creator fee");

        // 铸造代币
        memeToken.mint(msg.sender);

        if (msg.value > perMintPrice) {
            (bool refundSuccess,) = payable(msg.sender).call{value: msg.value - perMintPrice}("");
            require(refundSuccess, "MemeFactory: Failed to refund");
        }

        emit MemeMinted(tokenAddr, msg.sender, memeToken.perMint());
    }
}

contract Meme is ERC20 {
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
}
