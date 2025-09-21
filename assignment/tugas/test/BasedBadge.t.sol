// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import "../src/BasedBadge.sol";

contract BasedBadgeTest is Test {
    BasedBadge public basedBadge;
    address public owner;
    address public user1;
    address public user2;
    address public minter;

    // Events to test
    event TokenTypeCreated(uint256 indexed tokenId, string name, string category);
    event BadgeIssued(uint256 indexed tokenId, address to);
    event BatchBadgesIssued(uint256 indexed tokenId, uint256 count);
    event AchievementGranted(uint256 indexed tokenId, address student, string achievement);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        minter = makeAddr("minter");

        basedBadge = new BasedBadge();
        
        // Grant minter role to minter address
        basedBadge.grantRole(basedBadge.MINTER_ROLE(), minter);
    }

    function testInitialSetup() public {
        // Test initial roles
        assertTrue(basedBadge.hasRole(basedBadge.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(basedBadge.hasRole(basedBadge.MINTER_ROLE(), owner));
        assertTrue(basedBadge.hasRole(basedBadge.MINTER_ROLE(), minter));
        assertTrue(basedBadge.hasRole(basedBadge.URI_SETTER_ROLE(), owner));
        assertTrue(basedBadge.hasRole(basedBadge.PAUSER_ROLE(), owner));
    }

    function testCreateBadgeType() public {
        // Test creating a certificate type
        vm.expectEmit(true, false, false, true);
        emit TokenTypeCreated(1000, "Test Certificate", "certificate");
        
        uint256 tokenId = basedBadge.createBadgeType(
            "Test Certificate",
            "certificate",
            100,
            false,
            "https://example.com/cert.json"
        );
        
        assertEq(tokenId, 1000);
        
        // Check token info
        (string memory name, string memory category, uint256 maxSupply, bool isTransferable, uint256 validUntil, address issuer) = basedBadge.tokenInfo(tokenId);
        assertEq(name, "Test Certificate");
        assertEq(category, "certificate");
        assertEq(maxSupply, 100);
        assertFalse(isTransferable);
        assertEq(validUntil, 0);
        assertEq(issuer, owner);
    }

    function testCreateDifferentBadgeCategories() public {
        // Test all category types
        uint256 certId = basedBadge.createBadgeType("Certificate", "certificate", 0, false, "");
        uint256 eventId = basedBadge.createBadgeType("Event Badge", "event", 1000, true, "");
        uint256 achievementId = basedBadge.createBadgeType("Achievement", "achievement", 10, false, "");
        uint256 workshopId = basedBadge.createBadgeType("Workshop", "workshop", 0, true, "");
        
        assertEq(certId, 1000);
        assertEq(eventId, 2000);
        assertEq(achievementId, 3000);
        assertEq(workshopId, 4000);
    }

    function testIssueBadge() public {
        // Create a badge type first
        uint256 tokenId = basedBadge.createBadgeType(
            "Test Badge",
            "event",
            100,
            true,
            "https://example.com/badge.json"
        );
        
        // Issue badge to user1
        vm.expectEmit(true, true, false, false);
        emit BadgeIssued(tokenId, user1);
        
        basedBadge.issueBadge(user1, tokenId);
        
        // Check balance
        assertEq(basedBadge.balanceOf(user1, tokenId), 1);
        
        // Check holder tokens
        uint256[] memory userTokens = basedBadge.getTokensByHolder(user1);
        assertEq(userTokens.length, 1);
        assertEq(userTokens[0], tokenId);
        
        // Check earned timestamp
        (bool valid, uint256 earnedTimestamp) = basedBadge.verifyBadge(user1, tokenId);
        assertTrue(valid);
        assertGt(earnedTimestamp, 0);
    }

    function testBatchIssueBadges() public {
        // Create a badge type
        uint256 tokenId = basedBadge.createBadgeType(
            "Batch Badge",
            "event",
            1000,
            true,
            ""
        );
        
        // Prepare recipients
        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = makeAddr("user3");
        
        // Batch issue
        vm.expectEmit(true, false, false, true);
        emit BatchBadgesIssued(tokenId, 3);
        
        basedBadge.batchIssueBadges(recipients, tokenId, 2);
        
        // Check all recipients received badges
        for (uint i = 0; i < recipients.length; i++) {
            assertEq(basedBadge.balanceOf(recipients[i], tokenId), 2);
        }
    }

    function testGrantAchievement() public {
        vm.expectEmit(false, true, false, true);
        emit AchievementGranted(3000, user1, "First Achievement");
        
        uint256 achievementId = basedBadge.grantAchievement(user1, "First Achievement", 1);
        
        assertEq(achievementId, 3000);
        assertEq(basedBadge.balanceOf(user1, achievementId), 1);
        
        // Check token info
        (, string memory category, uint256 maxSupply, bool isTransferable,,) = basedBadge.tokenInfo(achievementId);
        assertEq(category, "achievement");
        assertEq(maxSupply, 1); // legendary rarity
        assertFalse(isTransferable);
    }

    function testCreateWorkshop() public {
        uint256[] memory sessionIds = basedBadge.createWorkshop("Advanced Solidity", 3);
        
        assertEq(sessionIds.length, 3);
        assertEq(sessionIds[0], 4000);
        assertEq(sessionIds[1], 4001);
        assertEq(sessionIds[2], 4002);
        
        // Check first session info
        (string memory name, string memory category,,,, ) = basedBadge.tokenInfo(sessionIds[0]);
        assertEq(name, "Advanced Solidity - Session 1");
        assertEq(category, "workshop");
    }

    function testTransferRestrictions() public {
        // Create non-transferable badge
        uint256 nonTransferableId = basedBadge.createBadgeType(
            "Non-Transferable",
            "certificate",
            0,
            false,
            ""
        );
        
        // Create transferable badge
        uint256 transferableId = basedBadge.createBadgeType(
            "Transferable",
            "event",
            0,
            true,
            ""
        );
        
        // Issue both to user1
        basedBadge.issueBadge(user1, nonTransferableId);
        basedBadge.issueBadge(user1, transferableId);
        
        // Try to transfer non-transferable (should fail)
        vm.prank(user1);
        vm.expectRevert("This token is non-transferable");
        basedBadge.safeTransferFrom(user1, user2, nonTransferableId, 1, "");
        
        // Transfer transferable (should succeed)
        vm.prank(user1);
        basedBadge.safeTransferFrom(user1, user2, transferableId, 1, "");
        
        assertEq(basedBadge.balanceOf(user2, transferableId), 1);
        assertEq(basedBadge.balanceOf(user1, transferableId), 0);
    }

    function testPauseUnpause() public {
        uint256 tokenId = basedBadge.createBadgeType("Test", "event", 0, true, "");
        basedBadge.issueBadge(user1, tokenId);
        
        // Pause contract
        basedBadge.pause();
        
        // Try to transfer while paused (should fail)
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        basedBadge.safeTransferFrom(user1, user2, tokenId, 1, "");
        
        // Unpause
        basedBadge.unpause();
        
        // Transfer should work now
        vm.prank(user1);
        basedBadge.safeTransferFrom(user1, user2, tokenId, 1, "");
        
        assertEq(basedBadge.balanceOf(user2, tokenId), 1);
    }

    function testAccessControl() public {
        // Test unauthorized minting
        vm.prank(user1);
        vm.expectRevert();
        basedBadge.createBadgeType("Unauthorized", "event", 0, true, "");
        
        // Test minter role
        vm.prank(minter);
        uint256 tokenId = basedBadge.createBadgeType("Authorized", "event", 0, true, "");
        assertEq(tokenId, 2000);
    }

    function testSetURI() public {
        uint256 tokenId = basedBadge.createBadgeType("Test", "event", 0, true, "initial-uri");
        
        // Set new URI
        string memory newURI = "https://new-uri.com/metadata.json";
        basedBadge.setURI(tokenId, newURI);
        
        assertEq(basedBadge.uri(tokenId), newURI);
    }

    function testSupplyLimits() public {
        // Create badge with limited supply
        uint256 tokenId = basedBadge.createBadgeType("Limited", "event", 2, true, "");
        
        // Issue to max supply
        basedBadge.issueBadge(user1, tokenId);
        basedBadge.issueBadge(user2, tokenId);
        
        // Try to issue beyond limit
        vm.expectRevert("Max supply reached");
        basedBadge.issueBadge(makeAddr("user3"), tokenId);
    }

    function testInvalidCategory() public {
        vm.expectRevert("Invalid category");
        basedBadge.createBadgeType("Invalid", "invalid-category", 0, true, "");
    }
}