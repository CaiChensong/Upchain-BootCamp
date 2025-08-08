// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "forge-std/Test.sol";
import "../src/v2-core/UniswapV2Factory.sol";
import "../src/v2-periphery/UniswapV2Router02.sol";
import "../src/v2-periphery/test/WETH9.sol";

contract RouterAddLiquidityTest is Test {
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;
    WETH9 public weth;
    MockERC20 public mockToken;

    address public user = address(1);
    address public feeToSetter = address(2);

    function setUp() public {
        // Deploy contracts
        weth = new WETH9();
        factory = new UniswapV2Factory(feeToSetter);
        router = new UniswapV2Router02(address(factory), address(weth));
        mockToken = new MockERC20();

        // Setup user with ETH and tokens
        vm.deal(user, 100 ether);
        mockToken.mint(user, 1000 * 10 ** 18); // 1000 tokens

        // Start acting as user
        vm.startPrank(user);
    }

    function testAddLiquidity() public {
        // User deposits ETH to get WETH
        weth.deposit{value: 10 ether}();

        // User approves router to spend tokens
        weth.approve(address(router), type(uint256).max);
        mockToken.approve(address(router), type(uint256).max);

        // Get initial balances
        uint256 initialWethBalance = weth.balanceOf(user);
        uint256 initialMockBalance = mockToken.balanceOf(user);
        uint256 initialEthBalance = user.balance;

        console.log("Initial balances:");
        console.log("WETH:", initialWethBalance);
        console.log("Mock Token:", initialMockBalance);
        console.log("ETH:", initialEthBalance);

        // Add liquidity
        uint256 wethAmount = 5 ether;
        uint256 mockAmount = 500 * 10 ** 18;
        uint256 wethMin = 4.5 ether;
        uint256 mockMin = 450 * 10 ** 18;

        (uint256 amountWeth, uint256 amountMock, uint256 liquidity) = router.addLiquidity(
            address(weth), address(mockToken), wethAmount, mockAmount, wethMin, mockMin, user, block.timestamp + 300
        );

        console.log("\nAdd liquidity result:");
        console.log("WETH added:", amountWeth);
        console.log("Mock tokens added:", amountMock);
        console.log("LP tokens received:", liquidity);

        // Get final balances
        uint256 finalWethBalance = weth.balanceOf(user);
        uint256 finalMockBalance = mockToken.balanceOf(user);
        uint256 finalEthBalance = user.balance;

        console.log("\nFinal balances:");
        console.log("WETH:", finalWethBalance);
        console.log("Mock Token:", finalMockBalance);
        console.log("ETH:", finalEthBalance);

        // Verify the pair was created
        address pair = factory.getPair(address(weth), address(mockToken));
        assertTrue(pair != address(0), "Pair should be created");

        // Verify LP token balance
        uint256 lpBalance = IUniswapV2Pair(pair).balanceOf(user);
        assertEq(lpBalance, liquidity, "LP token balance should match returned liquidity");

        // Verify reserves
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        console.log("\nPair reserves:");
        console.log("Reserve0 (WETH):", reserve0);
        console.log("Reserve1 (Mock):", reserve1);

        // Verify amounts match expectations
        assertEq(amountWeth, wethAmount, "WETH amount should match desired amount");
        assertEq(amountMock, mockAmount, "Mock token amount should match desired amount");
        assertTrue(liquidity > 0, "Should receive LP tokens");

        console.log("\nTest passed! Successfully added liquidity to Uniswap V2 pair.");
    }

    function testAddLiquidityETH() public {
        // User approves router to spend mock tokens
        mockToken.approve(address(router), type(uint256).max);

        // Get initial balances
        uint256 initialEthBalance = user.balance;
        uint256 initialMockBalance = mockToken.balanceOf(user);

        console.log("Initial balances:");
        console.log("ETH:", initialEthBalance);
        console.log("Mock Token:", initialMockBalance);

        // Add liquidity with ETH
        uint256 ethAmount = 5 ether;
        uint256 mockAmount = 500 * 10 ** 18;
        uint256 ethMin = 4.5 ether;
        uint256 mockMin = 450 * 10 ** 18;

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{value: ethAmount}(
            address(mockToken), mockAmount, mockMin, ethMin, user, block.timestamp + 300
        );

        console.log("\nAdd liquidity ETH result:");
        console.log("Mock tokens added:", amountToken);
        console.log("ETH added:", amountETH);
        console.log("LP tokens received:", liquidity);

        // Get final balances
        uint256 finalEthBalance = user.balance;
        uint256 finalMockBalance = mockToken.balanceOf(user);

        console.log("\nFinal balances:");
        console.log("ETH:", finalEthBalance);
        console.log("Mock Token:", finalMockBalance);

        // Verify the pair was created
        address pair = factory.getPair(address(mockToken), address(weth));
        assertTrue(pair != address(0), "Pair should be created");

        // Verify LP token balance
        uint256 lpBalance = IUniswapV2Pair(pair).balanceOf(user);
        assertEq(lpBalance, liquidity, "LP token balance should match returned liquidity");

        // Verify amounts match expectations
        assertEq(amountToken, mockAmount, "Token amount should match desired amount");
        assertEq(amountETH, ethAmount, "ETH amount should match desired amount");
        assertTrue(liquidity > 0, "Should receive LP tokens");

        console.log("\nTest passed! Successfully added liquidity with ETH to Uniswap V2 pair.");
    }
}

// Mock ERC20 Token for testing
contract MockERC20 {
    string public name = "Mock Token";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
