// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/W6D4/SimpleLeverageDEX.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC token for testing
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000 * 1e18);
    }
}

contract SimpleLeverageDEXTest is Test {
    SimpleLeverageDEX public dex;
    MockUSDC public usdc;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 public constant INITIAL_VETH = 1000 * 1e18;
    uint256 public constant INITIAL_VUSDC = 1000000 * 1e18;

    function setUp() public {
        usdc = new MockUSDC();
        dex = new SimpleLeverageDEX(INITIAL_VETH, INITIAL_VUSDC, address(usdc));

        // Give test accounts some USDC
        usdc.transfer(alice, 10000 * 1e18);
        usdc.transfer(bob, 10000 * 1e18);
        usdc.transfer(charlie, 10000 * 1e18);

        console.log("=== Setup Complete ===");
        console.log("Initial vK:", dex.vK());
    }

    function testConstructor() public {
        console.log("=== Testing Constructor ===");
        assertEq(dex.vETHAmount(), INITIAL_VETH, "vETH amount should match");
        assertEq(dex.vUSDCAmount(), INITIAL_VUSDC, "vUSDC amount should match");
        assertEq(dex.vK(), INITIAL_VETH * INITIAL_VUSDC, "vK should be product of vETH and vUSDC");
        console.log("Constructor test passed");
    }

    function testOpenLongPosition() public {
        console.log("=== Testing Open Long Position ===");

        uint256 margin = 100 * 1e18;
        uint256 leverage = 3;
        bool isLong = true;

        vm.startPrank(alice);
        usdc.approve(address(dex), margin);

        uint256 balanceBefore = usdc.balanceOf(alice);
        dex.openPosition(margin, leverage, isLong);
        uint256 balanceAfter = usdc.balanceOf(alice);

        (uint256 userMargin, uint256 userBorrowed, int256 userPosition) = dex.getPositionInfo(alice);
        console.log("Position opened successfully");
        console.log("Margin:", userMargin / 1e18, "USDC");
        console.log("Borrowed:", userBorrowed / 1e18, "USDC");
        console.log("Position size:", userPosition);

        assertEq(userMargin, margin, "Margin should match");
        assertEq(userBorrowed, margin * (leverage - 1), "Borrowed amount should match");
        assertTrue(userPosition > 0, "Long position should be positive");

        console.log("Long position opened successfully");
        vm.stopPrank();
    }

    function testOpenShortPosition() public {
        console.log("=== Testing Open Short Position ===");

        uint256 margin = 100 * 1e18;
        uint256 leverage = 3;
        bool isLong = false;

        vm.startPrank(bob);
        usdc.approve(address(dex), margin);

        dex.openPosition(margin, leverage, isLong);

        (uint256 userMargin, uint256 userBorrowed, int256 userPosition) = dex.getPositionInfo(bob);
        console.log("Position opened successfully");
        console.log("Margin:", userMargin / 1e18, "USDC");
        console.log("Borrowed:", userBorrowed / 1e18, "USDC");
        console.log("Position size:", userPosition);

        assertEq(userMargin, margin, "Margin should match");
        assertEq(userBorrowed, margin * (leverage - 1), "Borrowed amount should match");
        assertTrue(userPosition < 0, "Short position should be negative");

        console.log("Short position opened successfully");
        vm.stopPrank();
    }

    function testClosePosition() public {
        console.log("=== Testing Close Position ===");

        uint256 margin = 100 * 1e18;
        uint256 leverage = 3;
        bool isLong = true;

        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, leverage, isLong);

        uint256 balanceBeforeClose = usdc.balanceOf(alice);
        dex.closePosition();
        uint256 balanceAfterClose = usdc.balanceOf(alice);

        console.log("USDC returned:", (balanceAfterClose - balanceBeforeClose) / 1e18);

        (uint256 userMargin, uint256 userBorrowed, int256 userPosition) = dex.getPositionInfo(alice);
        assertEq(userPosition, 0, "Position should be closed");

        console.log("Position closed successfully");
        vm.stopPrank();
    }

    function testLiquidatePosition() public {
        console.log("=== Testing Liquidate Position ===");

        uint256 margin = 100 * 1e18;
        uint256 leverage = 3;
        bool isLong = true;

        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, leverage, isLong);
        vm.stopPrank();

        vm.startPrank(bob);
        dex.liquidatePosition(alice);
        vm.stopPrank();

        (,, int256 userPosition) = dex.getPositionInfo(alice);
        console.log("Position after liquidation attempt:", userPosition);

        console.log("Liquidation test completed");
    }

    function testCalculatePnL() public {
        console.log("=== Testing Calculate PnL ===");

        uint256 margin = 100 * 1e18;
        uint256 leverage = 3;
        bool isLong = true;

        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, leverage, isLong);

        int256 pnl = dex.calculatePnL(alice);
        console.log("Calculated PnL:", pnl);

        assertTrue(pnl != 0, "PnL should not be zero for open position");

        console.log("PnL calculation test passed");
        vm.stopPrank();
    }

    function testCannotOpenMultiplePositions() public {
        console.log("=== Testing Cannot Open Multiple Positions ===");

        uint256 margin = 100 * 1e18;
        uint256 leverage = 3;
        bool isLong = true;

        vm.startPrank(alice);
        usdc.approve(address(dex), margin * 2);

        dex.openPosition(margin, leverage, isLong);
        console.log("First position opened successfully");

        vm.expectRevert("Position already open");
        dex.openPosition(margin, leverage, isLong);

        console.log("Second position correctly rejected");
        vm.stopPrank();
    }

    function testCannotCloseEmptyPosition() public {
        console.log("=== Testing Cannot Close Empty Position ===");

        vm.startPrank(alice);

        vm.expectRevert("No open position");
        dex.closePosition();

        console.log("Empty position close correctly rejected");
        vm.stopPrank();
    }

    function testCannotLiquidateSelf() public {
        console.log("=== Testing Cannot Liquidate Self ===");

        uint256 margin = 100 * 1e18;
        uint256 leverage = 3;
        bool isLong = true;

        vm.startPrank(alice);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, leverage, isLong);

        vm.expectRevert("Cannot liquidate self");
        dex.liquidatePosition(alice);

        console.log("Self-liquidation correctly rejected");
        vm.stopPrank();
    }

    function testVirtualAssetPoolConsistency() public {
        console.log("=== Testing Virtual Asset Pool Consistency ===");

        uint256 margin = 100 * 1e18;
        uint256 leverage = 3;
        bool isLong = true;

        vm.startPrank(alice);
        usdc.approve(address(dex), margin);

        uint256 vKBefore = dex.vK();
        dex.openPosition(margin, leverage, isLong);
        uint256 vKAfter = dex.vK();

        console.log("vK before:", vKBefore);
        console.log("vK after:", vKAfter);
        console.log("vK difference:", vKBefore > vKAfter ? vKBefore - vKAfter : vKAfter - vKBefore);

        (uint256 userMargin, uint256 userBorrowed, int256 userPosition) = dex.getPositionInfo(alice);
        console.log("Position details:");
        console.log("Margin:", userMargin / 1e18, "USDC");
        console.log("Borrowed:", userBorrowed / 1e18, "USDC");
        console.log("Size:", userPosition);

        console.log("Virtual asset pool consistency test completed");
        vm.stopPrank();
    }
}
