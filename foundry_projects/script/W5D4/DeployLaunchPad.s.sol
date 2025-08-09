// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../../src/W5D4/LaunchPad.sol";

contract DeployLaunchPadScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // 从环境变量获取Uniswap Router地址
        address uniswapRouter = vm.envAddress("UNISWAP_V2_ROUTER");
        require(uniswapRouter != address(0), "UNISWAP_V2_ROUTER environment variable not set");

        vm.startBroadcast(deployerPrivateKey);

        MemeLaunchPad launchPad = new MemeLaunchPad(
            deployer, // projectOwner
            uniswapRouter // uniswapRouter
        );

        console.log("MemeLaunchPad deployed to:", address(launchPad));
        console.log("Project Owner:", deployer);
        console.log("Uniswap Router:", uniswapRouter);

        vm.stopBroadcast();
    }
}
