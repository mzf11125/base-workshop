// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import "../src/BasedToken.sol";

contract BasedTokenTest is Test {
    BasedToken public basedToken;
    address public owner;
    address public user1;
    address public user2;
    address public minter;

    uint256 constant INITIAL_SUPPLY = 1_000_000 * 10**18;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        minter = makeAddr("minter");

        basedToken = new BasedToken(INITIAL_SUPPLY);
        
        // Grant minter role to minter address
        basedToken.grantRole(basedToken.MINTER_ROLE(), minter);
    }

    function testInitialSetup() public {
        assertEq(basedToken.name(), "BasedToken");
        assertEq(basedToken.symbol(), "BASED");
        assertEq(basedToken.decimals(), 18);
        assertEq(basedToken.totalSupply(), INITIAL_SUPPLY);
        assertEq(basedToken.balanceOf(owner), INITIAL_SUPPLY);
        
        // Test initial roles
        assertTrue(basedToken.hasRole(basedToken.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(basedToken.hasRole(basedToken.MINTER_ROLE(), owner));
        assertTrue(basedToken.hasRole(basedToken.MINTER_ROLE(), minter));
        assertTrue(basedToken.hasRole(basedToken.PAUSER_ROLE(), owner));
    }

    function testMinting() public {
        uint256 mintAmount = 1000 * 10**18;
        uint256 initialBalance = basedToken.balanceOf(user1);
        
        // Test minting by owner
        basedToken.mint(user1, mintAmount);
        assertEq(basedToken.balanceOf(user1), initialBalance + mintAmount);
        
        // Test minting by minter role
        vm.prank(minter);
        basedToken.mint(user2, mintAmount);
        assertEq(basedToken.balanceOf(user2), mintAmount);
        
        // Test total supply increase
        assertEq(basedToken.totalSupply(), INITIAL_SUPPLY + (2 * mintAmount));
    }

    function testUnauthorizedMinting() public {
        vm.prank(user1);
        vm.expectRevert();
        basedToken.mint(user2, 1000);
    }

    function testMintToBlacklistedAddress() public {
        // Blacklist user1
        basedToken.setBlacklist(user1, true);
        
        // Try to mint to blacklisted address
        vm.expectRevert("Address is blacklisted");
        basedToken.mint(user1, 1000);
    }

    function testPauseUnpause() public {
        // Transfer some tokens to user1 first
        basedToken.transfer(user1, 1000);
        
        // Pause the contract
        basedToken.pause();
        
        // Try to transfer while paused
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        basedToken.transfer(user2, 500);
        
        // Unpause
        basedToken.unpause();
        
        // Transfer should work now
        vm.prank(user1);
        basedToken.transfer(user2, 500);
        assertEq(basedToken.balanceOf(user2), 500);
        assertEq(basedToken.balanceOf(user1), 500);
    }

    function testUnauthorizedPause() public {
        vm.prank(user1);
        vm.expectRevert();
        basedToken.pause();
        
        vm.prank(user1);
        vm.expectRevert();
        basedToken.unpause();
    }

    function testBlacklisting() public {
        // Transfer tokens to users first
        basedToken.transfer(user1, 1000);
        basedToken.transfer(user2, 1000);
        
        // Blacklist user1
        basedToken.setBlacklist(user1, true);
        assertTrue(basedToken.blacklisted(user1));
        
        // user1 cannot send tokens
        vm.prank(user1);
        vm.expectRevert("Blacklisted address cannot transfer");
        basedToken.transfer(user2, 500);
        
        // user1 cannot receive tokens
        vm.prank(user2);
        vm.expectRevert("Blacklisted address cannot transfer");
        basedToken.transfer(user1, 500);
        
        // Remove from blacklist
        basedToken.setBlacklist(user1, false);
        assertFalse(basedToken.blacklisted(user1));
        
        // Transfers should work now
        vm.prank(user1);
        basedToken.transfer(user2, 500);
        assertEq(basedToken.balanceOf(user1), 500);
        assertEq(basedToken.balanceOf(user2), 1500);
    }

    function testUnauthorizedBlacklisting() public {
        vm.prank(user1);
        vm.expectRevert();
        basedToken.setBlacklist(user2, true);
    }

    function testClaimReward() public {
        uint256 initialBalance = basedToken.balanceOf(user1);
        uint256 rewardAmount = 1 * 10**18; // 1 token
        
        // First claim should work
        vm.prank(user1);
        basedToken.claimReward();
        assertEq(basedToken.balanceOf(user1), initialBalance + rewardAmount);
        assertEq(basedToken.lastClaim(user1), block.timestamp);
        
        // Immediate second claim should fail
        vm.prank(user1);
        vm.expectRevert("Can only claim once per day");
        basedToken.claimReward();
        
        // Fast forward 1 day
        vm.warp(block.timestamp + 1 days);
        
        // Should be able to claim again
        vm.prank(user1);
        basedToken.claimReward();
        assertEq(basedToken.balanceOf(user1), initialBalance + (2 * rewardAmount));
    }

    function testClaimRewardBlacklisted() public {
        // Blacklist user1
        basedToken.setBlacklist(user1, true);
        
        // Try to claim reward
        vm.prank(user1);
        vm.expectRevert("Address is blacklisted");
        basedToken.claimReward();
    }

    function testBurning() public {
        uint256 burnAmount = 1000 * 10**18;
        
        // Transfer some tokens to user1
        basedToken.transfer(user1, burnAmount);
        
        uint256 initialSupply = basedToken.totalSupply();
        uint256 initialBalance = basedToken.balanceOf(user1);
        
        // Burn tokens
        vm.prank(user1);
        basedToken.burn(burnAmount);
        
        assertEq(basedToken.balanceOf(user1), initialBalance - burnAmount);
        assertEq(basedToken.totalSupply(), initialSupply - burnAmount);
    }

    function testBurnFrom() public {
        uint256 burnAmount = 1000 * 10**18;
        
        // Transfer tokens to user1
        basedToken.transfer(user1, burnAmount);
        
        // user1 approves user2 to burn tokens
        vm.prank(user1);
        basedToken.approve(user2, burnAmount);
        
        uint256 initialSupply = basedToken.totalSupply();
        
        // user2 burns user1's tokens
        vm.prank(user2);
        basedToken.burnFrom(user1, burnAmount);
        
        assertEq(basedToken.balanceOf(user1), 0);
        assertEq(basedToken.totalSupply(), initialSupply - burnAmount);
        assertEq(basedToken.allowance(user1, user2), 0);
    }

    function testStandardERC20Functions() public {
        uint256 transferAmount = 1000 * 10**18;
        
        // Transfer
        basedToken.transfer(user1, transferAmount);
        assertEq(basedToken.balanceOf(user1), transferAmount);
        
        // Approve and transferFrom
        vm.prank(user1);
        basedToken.approve(user2, transferAmount);
        assertEq(basedToken.allowance(user1, user2), transferAmount);
        
        vm.prank(user2);
        basedToken.transferFrom(user1, owner, transferAmount);
        assertEq(basedToken.balanceOf(user1), 0);
        assertEq(basedToken.balanceOf(owner), INITIAL_SUPPLY); // Back to original
        assertEq(basedToken.allowance(user1, user2), 0);
    }

    function testComplexScenario() public {
        // Scenario: Workshop reward system
        
        // 1. Mint tokens for workshop rewards
        vm.prank(minter);
        basedToken.mint(address(this), 10000 * 10**18);
        
        // 2. Distribute to participants
        address[] memory participants = new address[](3);
        participants[0] = user1;
        participants[1] = user2;
        participants[2] = makeAddr("user3");
        
        for (uint i = 0; i < participants.length; i++) {
            basedToken.transfer(participants[i], 1000 * 10**18);
        }
        
        // 3. Participants can claim daily rewards
        for (uint i = 0; i < participants.length; i++) {
            vm.prank(participants[i]);
            basedToken.claimReward();
            assertEq(basedToken.balanceOf(participants[i]), 1001 * 10**18);
        }
        
        // 4. One participant gets blacklisted
        basedToken.setBlacklist(user1, true);
        
        // 5. Emergency pause
        basedToken.pause();
        
        // 6. No transfers should work
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        basedToken.transfer(makeAddr("user3"), 100);
        
        // 7. Unpause and continue
        basedToken.unpause();
        
        vm.prank(user2);
        basedToken.transfer(makeAddr("user3"), 100 * 10**18);
        assertEq(basedToken.balanceOf(makeAddr("user3")), 1101 * 10**18);
    }

    function testRoleManagement() public {
        address newMinter = makeAddr("newMinter");
        address newPauser = makeAddr("newPauser");
        
        // Grant new roles
        basedToken.grantRole(basedToken.MINTER_ROLE(), newMinter);
        basedToken.grantRole(basedToken.PAUSER_ROLE(), newPauser);
        
        // Test new minter can mint
        vm.prank(newMinter);
        basedToken.mint(user1, 1000);
        assertEq(basedToken.balanceOf(user1), 1000);
        
        // Test new pauser can pause
        vm.prank(newPauser);
        basedToken.pause();
        
        vm.prank(newPauser);
        basedToken.unpause();
        
        // Revoke roles
        basedToken.revokeRole(basedToken.MINTER_ROLE(), newMinter);
        basedToken.revokeRole(basedToken.PAUSER_ROLE(), newPauser);
        
        // Should not be able to mint/pause anymore
        vm.prank(newMinter);
        vm.expectRevert();
        basedToken.mint(user1, 1000);
        
        vm.prank(newPauser);
        vm.expectRevert();
        basedToken.pause();
    }
}