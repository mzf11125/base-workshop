// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import "../src/BasedBadge.sol";
import "../src/BasedCertificate.sol";
import "../src/BasedToken.sol";

contract DeployAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy all contracts
        console.log("Deploying all Based contracts...");
        
        // 1. Deploy BasedToken
        uint256 initialSupply = 1_000_000 * 10**18;
        BasedToken basedToken = new BasedToken(initialSupply);
        console.log("BasedToken deployed to:", address(basedToken));
        
        // 2. Deploy BasedBadge
        BasedBadge basedBadge = new BasedBadge();
        console.log("BasedBadge deployed to:", address(basedBadge));
        
        // 3. Deploy BasedCertificate
        BasedCertificate basedCertificate = new BasedCertificate();
        console.log("BasedCertificate deployed to:", address(basedCertificate));
        
        console.log("All contracts deployed successfully!");
        
        // Setup some initial data
        console.log("Setting up initial badge types...");
        
        // Create certificate type
        uint256 certificateId = basedBadge.createBadgeType(
            "Workshop Completion Certificate",
            "certificate",
            0,
            false,
            "https://example.com/metadata/workshop-cert.json"
        );
        
        // Create event badge type
        uint256 eventId = basedBadge.createBadgeType(
            "Base Workshop 2024 Attendee",
            "event",
            500,
            true,
            "https://example.com/metadata/workshop-badge.json"
        );
        
        // Create achievement type
        uint256 achievementId = basedBadge.grantAchievement(
            msg.sender,
            "First Deployer",
            1 // legendary
        );
        
        console.log("Certificate type ID:", certificateId);
        console.log("Event badge type ID:", eventId);
        console.log("Achievement ID:", achievementId);
        
        vm.stopBroadcast();
    }
}