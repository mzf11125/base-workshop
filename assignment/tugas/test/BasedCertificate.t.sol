// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import "../src/BasedCertificate.sol";

contract BasedCertificateTest is Test {
    BasedCertificate public basedCertificate;
    address public owner;
    address public user1;
    address public user2;

    // Events to test
    event CertificateIssued(uint256 indexed tokenId, address recipient, string course, string issuer);
    event CertificateRevoked(uint256 indexed tokenId);
    event CertificateUpdated(uint256 indexed tokenId, string newCourse);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        basedCertificate = new BasedCertificate();
    }

    function testInitialSetup() public {
        assertEq(basedCertificate.name(), "Based Certificate");
        assertEq(basedCertificate.symbol(), "BCERT");
        assertEq(basedCertificate.owner(), owner);
    }

    function testIssueCertificate() public {
        vm.expectEmit(true, true, false, true);
        emit CertificateIssued(1, user1, "Blockchain Development", "Base Academy");
        
        basedCertificate.issueCertificate(
            user1,
            "John Doe",
            "Blockchain Development",
            "Base Academy",
            "https://example.com/cert-metadata.json"
        );
        
        // Check ownership
        assertEq(basedCertificate.ownerOf(1), user1);
        assertEq(basedCertificate.balanceOf(user1), 1);
        
        // Check certificate data
        (string memory recipientName, string memory course, string memory issuer, uint256 issuedDate, bool valid) = basedCertificate.certificates(1);
        assertEq(recipientName, "John Doe");
        assertEq(course, "Blockchain Development");
        assertEq(issuer, "Base Academy");
        assertGt(issuedDate, 0);
        assertTrue(valid);
        
        // Check owner certificates
        uint256[] memory userCerts = basedCertificate.getCertificatesByOwner(user1);
        assertEq(userCerts.length, 1);
        assertEq(userCerts[0], 1);
        
        // Check URI
        assertEq(basedCertificate.tokenURI(1), "https://example.com/cert-metadata.json");
    }

    function testPreventDuplicateCertificates() public {
        // Issue first certificate
        basedCertificate.issueCertificate(
            user1,
            "John Doe",
            "Course A",
            "Issuer A",
            "uri1"
        );
        
        // Try to issue duplicate (same recipient, course, issuer)
        vm.expectRevert("Certificate already exists for this combination");
        basedCertificate.issueCertificate(
            user1,
            "John Doe",
            "Course A",
            "Issuer A",
            "uri2"
        );
        
        // Different course should work
        basedCertificate.issueCertificate(
            user1,
            "John Doe",
            "Course B",
            "Issuer A",
            "uri3"
        );
        
        assertEq(basedCertificate.balanceOf(user1), 2);
    }

    function testRevokeCertificate() public {
        // Issue certificate
        basedCertificate.issueCertificate(user1, "John", "Course", "Issuer", "uri");
        
        // Revoke it
        vm.expectEmit(true, false, false, false);
        emit CertificateRevoked(1);
        
        basedCertificate.revokeCertificate(1);
        
        // Check it's marked invalid
        (,,,, bool valid) = basedCertificate.certificates(1);
        assertFalse(valid);
        
        // NFT should still exist
        assertEq(basedCertificate.ownerOf(1), user1);
    }

    function testUpdateCertificate() public {
        // Issue certificate
        basedCertificate.issueCertificate(user1, "John", "Old Course", "Issuer", "uri");
        
        // Update course
        vm.expectEmit(true, false, false, true);
        emit CertificateUpdated(1, "New Course");
        
        basedCertificate.updateCertificate(1, "New Course");
        
        // Check updated data
        (, string memory course,,,) = basedCertificate.certificates(1);
        assertEq(course, "New Course");
    }

    function testBurnCertificate() public {
        // Issue certificates
        basedCertificate.issueCertificate(user1, "John", "Course A", "Issuer", "uri1");
        basedCertificate.issueCertificate(user1, "John", "Course B", "Issuer", "uri2");
        
        assertEq(basedCertificate.balanceOf(user1), 2);
        
        // Burn first certificate
        basedCertificate.burnCertificate(1);
        
        // Check it's burned
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 1));
        basedCertificate.ownerOf(1);
        
        assertEq(basedCertificate.balanceOf(user1), 1);
        
        // Check owner certificates mapping is updated
        uint256[] memory userCerts = basedCertificate.getCertificatesByOwner(user1);
        assertEq(userCerts.length, 1);
        assertEq(userCerts[0], 2); // Should be the second certificate
    }

    function testSoulboundBehavior() public {
        // Issue certificate
        basedCertificate.issueCertificate(user1, "John", "Course", "Issuer", "uri");
        
        // Try to transfer (should fail)
        vm.prank(user1);
        vm.expectRevert("Certificates are non-transferable");
        basedCertificate.transferFrom(user1, user2, 1);
        
        // Try safeTransferFrom (should also fail)
        vm.prank(user1);
        vm.expectRevert("Certificates are non-transferable");
        basedCertificate.safeTransferFrom(user1, user2, 1);
        
        // Try approve and transfer (should fail)
        vm.prank(user1);
        basedCertificate.approve(user2, 1);
        
        vm.prank(user2);
        vm.expectRevert("Certificates are non-transferable");
        basedCertificate.transferFrom(user1, user2, 1);
    }

    function testAccessControl() public {
        // Test unauthorized certificate issuance
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        basedCertificate.issueCertificate(user2, "Jane", "Course", "Issuer", "uri");
        
        // Test unauthorized revocation
        basedCertificate.issueCertificate(user1, "John", "Course", "Issuer", "uri");
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        basedCertificate.revokeCertificate(1);
        
        // Test unauthorized update
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        basedCertificate.updateCertificate(1, "New Course");
        
        // Test unauthorized burn
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        basedCertificate.burnCertificate(1);
    }

    function testMultipleCertificatesPerUser() public {
        // Issue multiple certificates to same user
        basedCertificate.issueCertificate(user1, "John", "Course A", "Issuer 1", "uri1");
        basedCertificate.issueCertificate(user1, "John", "Course B", "Issuer 1", "uri2");
        basedCertificate.issueCertificate(user1, "John", "Course A", "Issuer 2", "uri3");
        
        assertEq(basedCertificate.balanceOf(user1), 3);
        
        uint256[] memory userCerts = basedCertificate.getCertificatesByOwner(user1);
        assertEq(userCerts.length, 3);
        assertEq(userCerts[0], 1);
        assertEq(userCerts[1], 2);
        assertEq(userCerts[2], 3);
    }

    function testCertificateDataRetrieval() public {
        basedCertificate.issueCertificate(user1, "Alice Smith", "Smart Contract Security", "CyberSec Academy", "uri");
        
        (string memory recipientName, string memory course, string memory issuer, uint256 issuedDate, bool valid) = basedCertificate.certificates(1);
        
        assertEq(recipientName, "Alice Smith");
        assertEq(course, "Smart Contract Security");
        assertEq(issuer, "CyberSec Academy");
        assertTrue(valid);
        assertEq(issuedDate, block.timestamp);
    }

    function testNonExistentTokenOperations() public {
        // Test operations on non-existent tokens
        vm.expectRevert("Certificate does not exist");
        basedCertificate.revokeCertificate(999);
        
        vm.expectRevert("Certificate does not exist");
        basedCertificate.updateCertificate(999, "New Course");
        
        vm.expectRevert("BCERT: token does not exist");
        basedCertificate.burnCertificate(999);
    }

    function testSupportsInterface() public {
        // Test ERC721 interface support
        assertTrue(basedCertificate.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(basedCertificate.supportsInterface(0x5b5e139f)); // ERC721Metadata
    }
}