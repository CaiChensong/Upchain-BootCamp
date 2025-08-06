// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../../src/W5D1/UpgradeableNFT.sol";
import "../../src/W5D1/UpgradeableNFTMarket.sol";

contract UpgradeableContractV1 is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 部署 V1 实现合约
        UpgradeableNFTV1 upgradeableNFT = new UpgradeableNFTV1();
        console.log("UpgradeableNFTV1 deployed at:", address(upgradeableNFT));

        UpgradeableNFTMarketV1 upgradeableNFTMarket = new UpgradeableNFTMarketV1();
        console.log("UpgradeableNFTMarketV1 deployed at:", address(upgradeableNFTMarket));

        vm.stopBroadcast();
    }
}

contract UpgradeableContractV2 is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 部署 V2 实现合约
        UpgradeableNFTV2 upgradeableNFT = new UpgradeableNFTV2();
        console.log("UpgradeableNFTV2 deployed at:", address(upgradeableNFT));

        UpgradeableNFTMarketV2 upgradeableNFTMarket = new UpgradeableNFTMarketV2();
        console.log("UpgradeableNFTMarketV2 deployed at:", address(upgradeableNFTMarket));

        vm.stopBroadcast();
    }
}
