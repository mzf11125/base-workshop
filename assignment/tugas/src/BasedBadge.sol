// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title BasedBadge
 * @dev ERC1155 multi-token for badges, certificates, and achievements
 * Token types:
 * - Non-transferable certificates
 * - Fungible event badges
 * - Limited achievement medals
 * - Workshop session tokens
 */
contract BasedBadge is ERC1155, AccessControl, Pausable, ERC1155Supply {
    // --- Role definitions ---
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // --- Token ID ranges for organization ---
    uint256 public constant CERTIFICATE_BASE = 1000;
    uint256 public constant EVENT_BADGE_BASE = 2000;
    uint256 public constant ACHIEVEMENT_BASE = 3000;
    uint256 public constant WORKSHOP_BASE = 4000;

    // --- Token metadata structure ---
    struct TokenInfo {
        string name;
        string category;
        uint256 maxSupply;
        bool isTransferable;
        uint256 validUntil; // 0 = no expiry
        address issuer;
    }

    // --- Mappings ---
    mapping(uint256 => TokenInfo) public tokenInfo;
    mapping(uint256 => string) private _tokenURIs;
    mapping(address => uint256[]) public holderTokens;
    mapping(uint256 => mapping(address => uint256)) public earnedAt;

    // --- Counters for unique IDs ---
    uint256 private _certificateCounter;
    uint256 private _eventCounter;
    uint256 private _achievementCounter;
    uint256 private _workshopCounter;

    // --- Events ---
    event TokenTypeCreated(uint256 indexed tokenId, string name, string category);
    event BadgeIssued(uint256 indexed tokenId, address to);
    event BatchBadgesIssued(uint256 indexed tokenId, uint256 count);
    event AchievementGranted(uint256 indexed tokenId, address student, string achievement);

    constructor() ERC1155("") {
        // --- Setup roles ---
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(URI_SETTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    /**
     * @dev Create new badge or certificate type
     */
    function createBadgeType(
        string memory name,
        string memory category,
        uint256 maxSupply,
        bool transferable,
        string memory uri
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId;
        
        // Pick category range based on category string
        if (keccak256(abi.encodePacked(category)) == keccak256(abi.encodePacked("certificate"))) {
            tokenId = CERTIFICATE_BASE + _certificateCounter;
            _certificateCounter++;
        } else if (keccak256(abi.encodePacked(category)) == keccak256(abi.encodePacked("event"))) {
            tokenId = EVENT_BADGE_BASE + _eventCounter;
            _eventCounter++;
        } else if (keccak256(abi.encodePacked(category)) == keccak256(abi.encodePacked("achievement"))) {
            tokenId = ACHIEVEMENT_BASE + _achievementCounter;
            _achievementCounter++;
        } else if (keccak256(abi.encodePacked(category)) == keccak256(abi.encodePacked("workshop"))) {
            tokenId = WORKSHOP_BASE + _workshopCounter;
            _workshopCounter++;
        } else {
            revert("Invalid category");
        }
        
        // Store TokenInfo
        tokenInfo[tokenId] = TokenInfo({
            name: name,
            category: category,
            maxSupply: maxSupply,
            isTransferable: transferable,
            validUntil: 0, // No expiry by default
            issuer: msg.sender
        });
        
        // Save URI
        _tokenURIs[tokenId] = uri;
        
        // Emit event
        emit TokenTypeCreated(tokenId, name, category);
        
        return tokenId;
    }

    /**
     * @dev Issue single badge/certificate to user
     */
    function issueBadge(address to, uint256 tokenId) public onlyRole(MINTER_ROLE) {
        // Verify tokenId exists
        require(bytes(tokenInfo[tokenId].name).length > 0, "Token type does not exist");
        
        // Check supply limit
        if (tokenInfo[tokenId].maxSupply > 0) {
            require(totalSupply(tokenId) < tokenInfo[tokenId].maxSupply, "Max supply reached");
        }
        
        // Mint token to user
        _mint(to, tokenId, 1, "");
        
        // Record timestamp
        earnedAt[tokenId][to] = block.timestamp;
        
        // Save to holderTokens if not already present
        bool alreadyHas = false;
        uint256[] storage userTokens = holderTokens[to];
        for (uint256 i = 0; i < userTokens.length; i++) {
            if (userTokens[i] == tokenId) {
                alreadyHas = true;
                break;
            }
        }
        if (!alreadyHas) {
            holderTokens[to].push(tokenId);
        }
        
        // Emit event
        emit BadgeIssued(tokenId, to);
    }

    /**
     * @dev Batch mint badges for events
     */
    function batchIssueBadges(address[] memory recipients, uint256 tokenId, uint256 amount)
        public onlyRole(MINTER_ROLE)
    {
        require(bytes(tokenInfo[tokenId].name).length > 0, "Token type does not exist");
        
        // Check total supply won't exceed max
        if (tokenInfo[tokenId].maxSupply > 0) {
            require(
                totalSupply(tokenId) + (recipients.length * amount) <= tokenInfo[tokenId].maxSupply,
                "Batch would exceed max supply"
            );
        }
        
        // Loop through recipients
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            
            // Mint amount to each
            _mint(recipient, tokenId, amount, "");
            
            // Record timestamp
            earnedAt[tokenId][recipient] = block.timestamp;
            
            // Save to holderTokens if not already present
            bool alreadyHas = false;
            uint256[] storage userTokens = holderTokens[recipient];
            for (uint256 j = 0; j < userTokens.length; j++) {
                if (userTokens[j] == tokenId) {
                    alreadyHas = true;
                    break;
                }
            }
            if (!alreadyHas) {
                holderTokens[recipient].push(tokenId);
            }
        }
        
        // Emit event
        emit BatchBadgesIssued(tokenId, recipients.length);
    }

    /**
     * @dev Grant special achievement to student
     */
    function grantAchievement(address student, string memory achievementName, uint256 rarity)
        public onlyRole(MINTER_ROLE) returns (uint256)
    {
        // Generate achievement tokenId
        uint256 tokenId = ACHIEVEMENT_BASE + _achievementCounter;
        _achievementCounter++;
        
        // Store TokenInfo (rarity affects maxSupply: 1=legendary, 10=rare, 100=common)
        uint256 maxSupply = rarity == 1 ? 1 : (rarity <= 10 ? 10 : 100);
        tokenInfo[tokenId] = TokenInfo({
            name: achievementName,
            category: "achievement",
            maxSupply: maxSupply,
            isTransferable: false, // Achievements are soulbound
            validUntil: 0,
            issuer: msg.sender
        });
        
        // Mint 1 achievement NFT
        _mint(student, tokenId, 1, "");
        
        // Record timestamp and add to holder tokens
        earnedAt[tokenId][student] = block.timestamp;
        holderTokens[student].push(tokenId);
        
        // Emit event
        emit AchievementGranted(tokenId, student, achievementName);
        
        return tokenId;
    }

    /**
     * @dev Create workshop series with multiple sessions
     */
    function createWorkshop(string memory seriesName, uint256 totalSessions)
        public onlyRole(MINTER_ROLE) returns (uint256[] memory)
    {
        uint256[] memory sessionIds = new uint256[](totalSessions);
        
        // Loop for totalSessions
        for (uint256 i = 0; i < totalSessions; i++) {
            // Generate tokenIds under WORKSHOP_BASE
            uint256 tokenId = WORKSHOP_BASE + _workshopCounter;
            _workshopCounter++;
            
            // Store TokenInfo
            string memory sessionName = string(abi.encodePacked(seriesName, " - Session ", Strings.toString(i + 1)));
            tokenInfo[tokenId] = TokenInfo({
                name: sessionName,
                category: "workshop",
                maxSupply: 0, // Unlimited for workshop sessions
                isTransferable: true, // Workshop badges can be transferred
                validUntil: 0,
                issuer: msg.sender
            });
            
            sessionIds[i] = tokenId;
            emit TokenTypeCreated(tokenId, sessionName, "workshop");
        }
        
        return sessionIds;
    }

    /**
     * @dev Set metadata URI
     */
    function setURI(uint256 tokenId, string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        _tokenURIs[tokenId] = newuri;
    }

    /**
     * @dev Get all tokens owned by a student
     */
    function getTokensByHolder(address holder) public view returns (uint256[] memory) {
        return holderTokens[holder];
    }

    /**
     * @dev Verify badge validity
     */
    function verifyBadge(address holder, uint256 tokenId)
        public view returns (bool valid, uint256 earnedTimestamp)
    {
        // Check balance > 0
        bool hasBalance = balanceOf(holder, tokenId) > 0;
        
        // Check expiry (if any)
        bool notExpired = tokenInfo[tokenId].validUntil == 0 || block.timestamp <= tokenInfo[tokenId].validUntil;
        
        // Return status + timestamp
        valid = hasBalance && notExpired;
        earnedTimestamp = earnedAt[tokenId][holder];
    }

    /**
     * @dev Pause / unpause transfers
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Restrict transferability and check pause
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) whenNotPaused {
        // Restrict non-transferable tokens
        for (uint i = 0; i < ids.length; i++) {
            if (from != address(0) && to != address(0)) {
                require(
                    tokenInfo[ids[i]].isTransferable,
                    "This token is non-transferable"
                );
            }
        }
        super._update(from, to, ids, values);
    }

    /**
     * @dev Return custom URI
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        return _tokenURIs[tokenId];
    }

    /**
     * @dev Check interface support
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
