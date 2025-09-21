// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title BasedToken
 * @dev ERC20 token with role-based access, pausing, and burnable features
 * Use cases:
 * - Fungible tokens (utility token, governance token, etc.)
 */
contract BasedToken is ERC20, ERC20Burnable, Pausable, AccessControl {
    // Define role constants
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    mapping(address => bool) public blacklisted;   // ban certain users
    mapping(address => uint256) public lastClaim;  // track last reward claim

    constructor(uint256 initialSupply) ERC20("BasedToken", "BASED") {
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        
        // Mint initial supply to deployer
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Mint new tokens
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(!blacklisted[to], "Address is blacklisted");
        _mint(to, amount);
    }

    /**
     * @dev Pause all transfers
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Blacklist a user (only admin)
     */
    function setBlacklist(address user, bool status) public onlyRole(DEFAULT_ADMIN_ROLE) {
        blacklisted[user] = status;
    }

    /**
     * @dev Simple daily reward claim
     */
    function claimReward() public {
        require(!blacklisted[msg.sender], "Address is blacklisted");
        
        // Check if 1 day passed since last claim (allow first claim immediately)
        if (lastClaim[msg.sender] != 0) {
            require(block.timestamp >= lastClaim[msg.sender] + 1 days, "Can only claim once per day");
        }
        
        // Mint small reward to msg.sender (1 token)
        _mint(msg.sender, 1 * 10**decimals());
        
        // Update lastClaim
        lastClaim[msg.sender] = block.timestamp;
    }

    /**
     * @dev Hook to block transfers when paused
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        require(!blacklisted[from] && !blacklisted[to], "Blacklisted address cannot transfer");
        super._update(from, to, amount);
    }
}
