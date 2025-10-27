// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PulseNFT is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    
    struct Achievement {
        uint256 contestId;
        uint256 rank;
        uint256 score;
        uint256 wonAmount;
        uint256 mintedAt;
        bool isWinner;
    }
    
    // Token metadata
    mapping(uint256 => Achievement) public tokenAchievements;
    mapping(address => uint256[]) public userAchievements;
    mapping(uint256 => string) public contestTitles;
    
    // Metadata URIs
    string public baseURI;
    string public participantTokenURI;
    string public winnerTokenURI;
    
    address public owner;
    
    event AchievementMinted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 contestId,
        uint256 rank,
        bool isWinner
    );
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }
    
    constructor() ERC721("Pulse Achievements", "PULSE") {
        owner = msg.sender;
        baseURI = "https://api.pulse.com/nft/";
        participantTokenURI = "participant.json";
        winnerTokenURI = "winner.json";
    }
    
    function mintParticipantNFT(address _to, uint256 _contestId) external {
        require(_to != address(0), "Invalid address");
        
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        
        _mint(_to, tokenId);
        
        tokenAchievements[tokenId] = Achievement({
            contestId: _contestId,
            rank: 0,
            score: 0,
            wonAmount: 0,
            mintedAt: block.timestamp,
            isWinner: false
        });
        
        userAchievements[_to].push(tokenId);
        
        emit AchievementMinted(_to, tokenId, _contestId, 0, false);
    }
    
    function mintWinnerNFT(
        address _to, 
        uint256 _contestId, 
        uint256 _rank, 
        uint256 _wonAmount
    ) external {
        require(_to != address(0), "Invalid address");
        require(_rank > 0 && _rank <= 3, "Invalid rank");
        
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        
        _mint(_to, tokenId);
        
        tokenAchievements[tokenId] = Achievement({
            contestId: _contestId,
            rank: _rank,
            score: 0, // Would be set by scoring system
            wonAmount: _wonAmount,
            mintedAt: block.timestamp,
            isWinner: true
        });
        
        userAchievements[_to].push(tokenId);
        
        emit AchievementMinted(_to, tokenId, _contestId, _rank, true);
    }
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token doesn't exist");
        
        Achievement memory achievement = tokenAchievements[tokenId];
        
        if (achievement.isWinner) {
            return string(abi.encodePacked(baseURI, winnerTokenURI));
        } else {
            return string(abi.encodePacked(baseURI, participantTokenURI));
        }
    }
    
    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }
    
    function setTokenURIs(string memory _participantURI, string memory _winnerURI) external onlyOwner {
        participantTokenURI = _participantURI;
        winnerTokenURI = _winnerURI;
    }
    
    function setContestTitle(uint256 _contestId, string memory _title) external onlyOwner {
        contestTitles[_contestId] = _title;
    }
    
    function getUserAchievements(address _user) external view returns (uint256[] memory) {
        return userAchievements[_user];
    }
    
    function getAchievementDetails(uint256 _tokenId) external view returns (Achievement memory) {
        require(_exists(_tokenId), "Token doesn't exist");
        return tokenAchievements[_tokenId];
    }
    
    function getTotalMinted() external view returns (uint256) {
        return _tokenIdCounter.current();
    }
    
    // Soulbound tokens - disable transfers
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override {
        require(from == address(0) || to == address(0), "Soulbound token: cannot transfer");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
}