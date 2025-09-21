// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import "../src/BasedBadge.sol";

contract DeployBasedBadge is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy BasedBadge contract
        BasedBadge basedBadge = new BasedBadge();
        
        console.log("BasedBadge deployed to:", address(basedBadge));
        
        // Create some sample badge types
        uint256 certificateId = basedBadge.createBadgeType(
            "Workshop Completion Certificate",
            "certificate",
            0, // unlimited supply
            false, // non-transferable
            "https://example.com/metadata/certificate.json"
        );
        
        uint256 eventBadgeId = basedBadge.createBadgeType(
            "Conference Attendee Badge",
            "event",
            1000, // limited to 1000
            true, // transferable
            "https://example.com/metadata/event-badge.json"
        );
        
        console.log("Certificate token ID:", certificateId);
        console.log("Event badge token ID:", eventBadgeId);
        
        vm.stopBroadcast();
    }
}