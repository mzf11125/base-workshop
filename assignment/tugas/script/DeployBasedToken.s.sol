// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import "../src/BasedToken.sol";

contract DeployBasedToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy BasedToken contract with 1 million initial supply
        uint256 initialSupply = 1_000_000 * 10**18; // 1M tokens with 18 decimals
        BasedToken basedToken = new BasedToken(initialSupply);
        
        console.log("BasedToken deployed to:", address(basedToken));
        console.log("Initial supply:", initialSupply);
        console.log("Deployer balance:", basedToken.balanceOf(msg.sender));
        
        vm.stopBroadcast();
    }
}