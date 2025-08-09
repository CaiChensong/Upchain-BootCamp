// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "forge-std/Script.sol";
import "../src/v2-core/UniswapV2Factory.sol";
import "../src/v2-periphery/UniswapV2Router02.sol";
import "../src/v2-periphery/test/WETH9.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy WETH9
        WETH9 weth = new WETH9();

        // Deploy UniswapV2Factory
        UniswapV2Factory factory = new UniswapV2Factory(deployer);

        // Deploy UniswapV2Router02
        UniswapV2Router02 router = new UniswapV2Router02(address(factory), address(weth));

        vm.stopBroadcast();

        // Output deployment summary
        console.log("WETH9 deployed to:", address(weth));
        console.log("Factory deployed to:", address(factory));
        console.log("Router deployed to:", address(router));
    }
}
