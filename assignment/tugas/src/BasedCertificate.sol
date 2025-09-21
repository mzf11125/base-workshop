// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BasedCertificate
 * @dev NFT-based certificate system for achievements, graduation, or training
 * Features:
 * - Soulbound (non-transferable)
 * - Metadata for certificate details
 * - Issuer-controlled (onlyOwner)
 */
contract BasedCertificate is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    uint256 private _nextTokenId;

    struct CertificateData {
        string recipientName;
        string course;
        string issuer;
        uint256 issuedDate;
        bool valid;
    }

    // --- Mappings ---
    mapping(uint256 => CertificateData) public certificates;
    mapping(address => uint256[]) public ownerCertificates; // Track all certs per owner
    mapping(string => uint256) public certHashToTokenId; // Prevent duplicate certificate by hash

    // --- Events ---
    event CertificateIssued(
        uint256 indexed tokenId,
        address recipient,
        string course,
        string issuer
    );
    event CertificateRevoked(uint256 indexed tokenId);
    event CertificateUpdated(uint256 indexed tokenId, string newCourse);

    constructor() ERC721("Based Certificate", "BCERT") Ownable(msg.sender) {
        _nextTokenId = 1; // Start from 1 to avoid issues with 0 default value
    }

    /**
     * @dev Issue a new certificate
     * Use case: Awarding completion or graduation
     */
    function issueCertificate(
        address to,
        string memory recipientName,
        string memory course,
        string memory issuer,
        string memory uri
    ) public onlyOwner {
        // Check duplicate (optional: via hash)
        string memory certHash = string(abi.encodePacked(to, course, issuer));
        require(certHashToTokenId[certHash] == 0, "Certificate already exists for this combination");
        
        uint256 tokenId = _nextTokenId++;
        
        // Mint new NFT
        _safeMint(to, tokenId);
        
        // Set token URI (certificate metadata file)
        _setTokenURI(tokenId, uri);
        
        // Save certificate data
        certificates[tokenId] = CertificateData({
            recipientName: recipientName,
            course: course,
            issuer: issuer,
            issuedDate: block.timestamp,
            valid: true
        });
        
        // Update mappings
        ownerCertificates[to].push(tokenId);
        certHashToTokenId[certHash] = tokenId;
        
        // Emit event
        emit CertificateIssued(tokenId, to, course, issuer);
    }

    /**
     * @dev Revoke a certificate (e.g. if mistake or fraud)
     */
    function revokeCertificate(uint256 tokenId) public onlyOwner {
        // Check token exists
        require(_ownerOf(tokenId) != address(0), "Certificate does not exist");
        
        // Mark certificate invalid
        certificates[tokenId].valid = false;
        
        // Emit event
        emit CertificateRevoked(tokenId);
    }

    /**
     * @dev Update certificate data (optional, for corrections)
     */
    function updateCertificate(uint256 tokenId, string memory newCourse) public onlyOwner {
        // Check token exists
        require(_ownerOf(tokenId) != address(0), "Certificate does not exist");
        
        // Update course field
        certificates[tokenId].course = newCourse;
        
        // Emit event
        emit CertificateUpdated(tokenId, newCourse);
    }

    /**
     * @dev Get all certificates owned by an address
     */
    function getCertificatesByOwner(address owner)
        public
        view
        returns (uint256[] memory)
    {
        return ownerCertificates[owner];
    }
    
    /**
    * @dev Burn a certificate (soulbound cleanup)
    */
    function burnCertificate(uint256 tokenId) public onlyOwner {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "BCERT: token does not exist");
        
        // Clean up mappings before burning
        uint256[] storage ownerTokens = ownerCertificates[owner];
        for (uint256 i = 0; i < ownerTokens.length; i++) {
            if (ownerTokens[i] == tokenId) {
                ownerTokens[i] = ownerTokens[ownerTokens.length - 1];
                ownerTokens.pop();
                break;
            }
        }
        
        // Burn the NFT
        _burn(tokenId);
    }

    /**
     * @dev Override transfer functions to make non-transferable (soulbound)
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns(address){
        address from = _ownerOf(tokenId);
        // Only allow minting (from == address(0)) and burning (to == address(0))
        require(from == address(0) || to == address(0), "Certificates are non-transferable");
        return super._update(to, tokenId, auth);
    }

    // --- Overrides for multiple inheritance ---

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
