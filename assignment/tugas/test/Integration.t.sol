// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import "../src/BasedBadge.sol";
import "../src/BasedCertificate.sol";
import "../src/BasedToken.sol";

/**
 * @title Integration Test Suite
 * @dev Tests interaction between all three Based contracts
 */
contract IntegrationTest is Test {
    BasedBadge public badge;
    BasedCertificate public certificate;
    BasedToken public token;
    
    address public admin;
    address public student1;
    address public student2;
    address public instructor;

    function setUp() public {
        admin = address(this);
        student1 = makeAddr("student1");
        student2 = makeAddr("student2");
        instructor = makeAddr("instructor");

        // Deploy all contracts
        badge = new BasedBadge();
        certificate = new BasedCertificate();
        token = new BasedToken(1_000_000 * 10**18);
        
        // Setup roles
        badge.grantRole(badge.MINTER_ROLE(), instructor);
        token.grantRole(token.MINTER_ROLE(), instructor);
    }

    function testCompleteWorkshopFlow() public {
        // 1. Create a workshop series
        uint256[] memory sessionIds = badge.createWorkshop("Base Smart Contract Development", 4);
        assertEq(sessionIds.length, 4);
        
        // 2. Create completion certificate type
        uint256 certBadgeId = badge.createBadgeType(
            "Course Completion Badge",
            "certificate",
            0,
            false,
            "https://based.org/metadata/completion.json"
        );
        
        // 3. Students attend sessions and get session badges
        vm.startPrank(instructor);
        for (uint i = 0; i < sessionIds.length; i++) {
            badge.issueBadge(student1, sessionIds[i]);
            badge.issueBadge(student2, sessionIds[i]);
        }
        vm.stopPrank();
        
        // 4. Verify students have all session badges
        for (uint i = 0; i < sessionIds.length; i++) {
            assertEq(badge.balanceOf(student1, sessionIds[i]), 1);
            assertEq(badge.balanceOf(student2, sessionIds[i]), 1);
        }
        
        // 5. Issue completion badges
        vm.startPrank(instructor);
        badge.issueBadge(student1, certBadgeId);
        badge.issueBadge(student2, certBadgeId);
        vm.stopPrank();
        
        // 6. Issue official certificates
        certificate.issueCertificate(
            student1,
            "Alice Johnson",
            "Base Smart Contract Development",
            "Base Academy",
            "https://based.org/certificates/alice.json"
        );
        
        certificate.issueCertificate(
            student2,
            "Bob Smith",
            "Base Smart Contract Development", 
            "Base Academy",
            "https://based.org/certificates/bob.json"
        );
        
        // 7. Reward students with tokens
        vm.startPrank(instructor);
        token.mint(student1, 100 * 10**18); // 100 BASED tokens
        token.mint(student2, 100 * 10**18);
        vm.stopPrank();
        
        // 8. Verify final state
        uint256[] memory student1Badges = badge.getTokensByHolder(student1);
        uint256[] memory student2Badges = badge.getTokensByHolder(student2);
        
        assertEq(student1Badges.length, 5); // 4 sessions + 1 completion
        assertEq(student2Badges.length, 5);
        
        assertEq(certificate.balanceOf(student1), 1);
        assertEq(certificate.balanceOf(student2), 1);
        
        assertEq(token.balanceOf(student1), 100 * 10**18);
        assertEq(token.balanceOf(student2), 100 * 10**18);
    }

    function testTokenRewardSystem() public {
        // Create achievement badge type
        uint256 achievementId = badge.createBadgeType(
            "Top Performer",
            "achievement",
            10,
            false,
            "https://based.org/metadata/top-performer.json"
        );
        
        // Give achievement to student1
        vm.prank(instructor);
        badge.issueBadge(student1, achievementId);
        
        // Reward with extra tokens
        vm.prank(instructor);
        token.mint(student1, 50 * 10**18);
        
        // Student can claim daily rewards
        vm.prank(student1);
        token.claimReward();
        
        assertEq(token.balanceOf(student1), 51 * 10**18);
        
        // Verify achievement badge
        (bool valid, uint256 earnedAt) = badge.verifyBadge(student1, achievementId);
        assertTrue(valid);
        assertGt(earnedAt, 0);
    }

    function testCertificateVerification() public {
        // Issue certificate
        certificate.issueCertificate(
            student1,
            "Alice",
            "Advanced Solidity",
            "Base Academy",
            "metadata-uri"
        );
        
        // Create matching badge
        uint256 badgeId = badge.createBadgeType(
            "Advanced Solidity Graduate",
            "certificate",
            0,
            false,
            "badge-metadata-uri"
        );
        
        vm.prank(instructor);
        badge.issueBadge(student1, badgeId);
        
        // Verify both credentials exist
        assertEq(certificate.balanceOf(student1), 1);
        (bool badgeValid,) = badge.verifyBadge(student1, badgeId);
        assertTrue(badgeValid);
        
        // Certificate should be soulbound
        vm.prank(student1);
        vm.expectRevert("Certificates are non-transferable");
        certificate.transferFrom(student1, student2, 1);
        
        // Badge should also be soulbound (certificate category)
        vm.prank(student1);
        vm.expectRevert("This token is non-transferable");
        badge.safeTransferFrom(student1, student2, badgeId, 1, "");
    }

    function testEventBadgeTrading() public {
        // Create transferable event badge
        uint256 eventBadgeId = badge.createBadgeType(
            "ETH Denver 2024",
            "event",
            1000,
            true,
            "event-metadata"
        );
        
        // Issue to both students
        vm.startPrank(instructor);
        badge.issueBadge(student1, eventBadgeId);
        badge.issueBadge(student2, eventBadgeId);
        vm.stopPrank();
        
        // Students can trade event badges (unlike certificates)
        vm.prank(student1);
        badge.safeTransferFrom(student1, student2, eventBadgeId, 1, "");
        
        assertEq(badge.balanceOf(student1, eventBadgeId), 0);
        assertEq(badge.balanceOf(student2, eventBadgeId), 2);
    }

    function testAccessControlAcrossContracts() public {
        // Only authorized minters should be able to issue badges
        vm.prank(student1);
        vm.expectRevert();
        badge.createBadgeType("Unauthorized", "event", 0, true, "");
        
        // Only owner should issue certificates
        vm.prank(student1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", student1));
        certificate.issueCertificate(student2, "Name", "Course", "Issuer", "uri");
        
        // Only minters should mint tokens
        vm.prank(student1);
        vm.expectRevert();
        token.mint(student2, 1000);
    }

    function testPauseAllContracts() public {
        // Issue some tokens and badges first
        vm.startPrank(instructor);
        token.mint(student1, 1000 * 10**18);
        uint256 badgeId = badge.createBadgeType("Test Badge", "event", 0, true, "");
        badge.issueBadge(student1, badgeId);
        vm.stopPrank();
        
        certificate.issueCertificate(student1, "Test", "Course", "Issuer", "uri");
        
        // Pause badge contract
        badge.pause();
        
        vm.prank(student1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        badge.safeTransferFrom(student1, student2, badgeId, 1, "");
        
        // Pause token contract
        token.pause();
        
        vm.prank(student1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        token.transfer(student2, 100);
        
        // Certificate transfers should fail anyway (soulbound)
        vm.prank(student1);
        vm.expectRevert("Certificates are non-transferable");
        certificate.transferFrom(student1, student2, 1);
        
        // Unpause and test transfers work
        badge.unpause();
        token.unpause();
        
        vm.prank(student1);
        badge.safeTransferFrom(student1, student2, badgeId, 1, "");
        
        vm.prank(student1);
        token.transfer(student2, 100 * 10**18);
        
        assertEq(badge.balanceOf(student2, badgeId), 1);
        assertEq(token.balanceOf(student2), 100 * 10**18);
    }

    function testBatchOperations() public {
        // Create event badge for batch issuance
        uint256 eventBadgeId = badge.createBadgeType(
            "Conference Attendee",
            "event",
            100,
            true,
            "conference-badge-uri"
        );
        
        // Batch issue to multiple students
        address[] memory attendees = new address[](3);
        attendees[0] = student1;
        attendees[1] = student2;
        attendees[2] = makeAddr("student3");
        
        vm.prank(instructor);
        badge.batchIssueBadges(attendees, eventBadgeId, 1);
        
        // Verify all received badges
        for (uint i = 0; i < attendees.length; i++) {
            assertEq(badge.balanceOf(attendees[i], eventBadgeId), 1);
        }
        
        // Issue tokens to all
        vm.startPrank(instructor);
        for (uint i = 0; i < attendees.length; i++) {
            token.mint(attendees[i], 50 * 10**18);
        }
        vm.stopPrank();
        
        // All can claim daily rewards
        for (uint i = 0; i < attendees.length; i++) {
            vm.prank(attendees[i]);
            token.claimReward();
            assertEq(token.balanceOf(attendees[i]), 51 * 10**18);
        }
    }

    function testSupplyLimitsAndAchievements() public {
        // Create limited achievement
        uint256 rareAchievementId = badge.createBadgeType(
            "Genesis NFT Holder",
            "achievement",
            3, // Only 3 available
            false,
            "rare-achievement-uri"
        );
        
        // Issue to students
        vm.startPrank(instructor);
        badge.issueBadge(student1, rareAchievementId);
        badge.issueBadge(student2, rareAchievementId);
        badge.issueBadge(makeAddr("student3"), rareAchievementId);
        
        // Try to issue beyond limit
        vm.expectRevert("Max supply reached");
        badge.issueBadge(makeAddr("student4"), rareAchievementId);
        vm.stopPrank();
        
        // Grant legendary achievement
        vm.prank(instructor);
        uint256 legendaryId = badge.grantAchievement(student1, "First Smart Contract Deploy", 1);
        
        // Check rarity constraints
        (, , uint256 maxSupply, ,, ) = badge.tokenInfo(legendaryId);
        assertEq(maxSupply, 1); // Legendary should have max supply of 1
        
        assertEq(badge.balanceOf(student1, legendaryId), 1);
    }
}