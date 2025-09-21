// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import "../src/BasedCertificate.sol";

contract DeployBasedCertificate is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy BasedCertificate contract
        BasedCertificate basedCertificate = new BasedCertificate();
        
        console.log("BasedCertificate deployed to:", address(basedCertificate));
        
        // Issue a sample certificate
        address sampleRecipient = 0x1234567890123456789012345678901234567890;
        basedCertificate.issueCertificate(
            sampleRecipient,
            "John Doe",
            "Blockchain Development Course",
            "Base Workshop Academy",
            "https://example.com/metadata/certificate-1.json"
        );
        
        console.log("Sample certificate issued to:", sampleRecipient);
        
        vm.stopBroadcast();
    }
}