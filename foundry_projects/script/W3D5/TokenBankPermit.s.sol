// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// forge script script/W3D5/TokenBankPermit.s.sol --private-key $PRIVATE_KEY --rpc-url $LOCAL_RPC_URL --broadcast

import {Script, console} from "forge-std/Script.sol";
import "../../src/W3D5/ERC20PermitToken.sol";
import "../../src/W3D5/TokenBankPermit.sol";

contract TokenBankPermitScript is Script {
    ERC20PermitToken public token;
    TokenBankPermit public tokenBank;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Permit2合约与当前项目存在编译器版本冲突，需要单独部署Permit2
        // Permit2 permit2 = new Permit2();
        // console.log("Permit2 deployed at:", address(permit2));

        address permit2 = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);

        // 部署ERC20PermitToken
        token = new ERC20PermitToken("ERC20PermitToken", "EPTK");
        console.log("ERC20PermitToken deployed at:", address(token));

        // 部署TokenBankPermit，传入token地址
        tokenBank = new TokenBankPermit(address(token), permit2);
        console.log("TokenBankPermit deployed at:", address(tokenBank));

        vm.stopBroadcast();
    }
}
