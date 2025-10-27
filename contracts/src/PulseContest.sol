// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./PulseNFT.sol";

contract PulseContest is ReentrancyGuard {
    enum ContestState { ACTIVE, ENDED, PAID_OUT }
    
    struct Participant {
        address creator;
        string twitterHandle;
        string[] submittedPosts;
        uint256 totalScore;
        uint256 joinedAt;
        bool isActive;
    }
    
    struct Post {
        string url;
        uint256 submittedAt;
        uint256 score;
        bool verified;
    }
    
    // Contest configuration
    string public title;
    string public rules;
    uint256 public prizePool;
    uint256 public startTime;
    uint256 public endTime;
    address public creator;
    address public rewardToken;
    ContestState public state;
    
    // Participant management
    address[] public participants;
    mapping(address => Participant) public participantInfo;
    mapping(address => bool) public hasJoined;
    mapping(address => Post[]) public userPosts;
    
    // Scoring and winners
    address[3] public winners; // [1st, 2nd, 3rd]
    uint256[3] public prizeDistribution = [5000, 3000, 2000]; // 50%, 30%, 20%
    
    // External contracts
    PulseNFT public nftContract;
    address public factory;
    
    // Events
    event ParticipantJoined(address indexed participant, string twitterHandle);
    event PostSubmitted(address indexed participant, string postUrl);
    event ScoreUpdated(address indexed participant, uint256 newScore);
    event ContestFinalized(address[3] winners);
    event PrizesDistributed(address[3] winners, uint256[3] amounts);
    
    modifier onlyActive() {
        require(state == ContestState.ACTIVE, "Contest not active");
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Contest not in progress");
        _;
    }
    
    modifier onlyCreator() {
        require(msg.sender == creator, "Only contest creator can call this");
        _;
    }
    
    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory can call this");
        _;
    }
    
    constructor(
        string memory _title,
        uint256 _prizePool,
        uint256 _duration,
        string memory _rules,
        address _rewardToken,
        address _creator
    ) payable {
        title = _title;
        prizePool = _prizePool;
        startTime = block.timestamp;
        endTime = block.timestamp + _duration;
        rules = _rules;
        rewardToken = _rewardToken;
        creator = _creator;
        state = ContestState.ACTIVE;
        factory = msg.sender;
    }
    
    function joinContest(string memory _twitterHandle) external onlyActive {
        require(!hasJoined[msg.sender], "Already joined contest");
        require(bytes(_twitterHandle).length > 0, "Twitter handle required");
        
        participants.push(msg.sender);
        hasJoined[msg.sender] = true;
        
        participantInfo[msg.sender] = Participant({
            creator: msg.sender,
            twitterHandle: _twitterHandle,
            submittedPosts: new string[](0),
            totalScore: 0,
            joinedAt: block.timestamp,
            isActive: true
        });
        
        emit ParticipantJoined(msg.sender, _twitterHandle);
    }
    
    function submitPost(string memory _postUrl) external onlyActive {
        require(hasJoined[msg.sender], "Must join contest first");
        require(bytes(_postUrl).length > 0, "Post URL required");
        
        Participant storage participant = participantInfo[msg.sender];
        participant.submittedPosts.push(_postUrl);
        
        userPosts[msg.sender].push(Post({
            url: _postUrl,
            submittedAt: block.timestamp,
            score: 0,
            verified: false
        }));
        
        emit PostSubmitted(msg.sender, _postUrl);
    }
    
    function updateScore(address _participant, uint256 _newScore) external onlyFactory {
        require(hasJoined[_participant], "Participant not found");
        
        Participant storage participant = participantInfo[_participant];
        participant.totalScore = _newScore;
        
        // Update individual post scores (simplified - in practice you'd track which post)
        for (uint256 i = 0; i < userPosts[_participant].length; i++) {
            if (!userPosts[_participant][i].verified) {
                userPosts[_participant][i].score = _newScore;
                userPosts[_participant][i].verified = true;
                break;
            }
        }
        
        emit ScoreUpdated(_participant, _newScore);
    }
    
    function finalizeContest() external onlyCreator {
        require(state == ContestState.ACTIVE, "Contest not active");
        require(block.timestamp > endTime, "Contest not ended yet");
        
        state = ContestState.ENDED;
        
        // Simple leaderboard calculation (in practice, use off-chain computation)
        _calculateWinners();
        
        emit ContestFinalized(winners);
    }
    
    function distributePrizes() external nonReentrant onlyCreator {
        require(state == ContestState.ENDED, "Contest not finalized");
        require(winners[0] != address(0), "No winners calculated");
        
        state = ContestState.PAID_OUT;
        
        uint256[3] memory prizeAmounts;
        bool distributionSuccess = true;
        
        for (uint256 i = 0; i < 3; i++) {
            if (winners[i] != address(0)) {
                prizeAmounts[i] = (prizePool * prizeDistribution[i]) / 10000;
                
                (bool success, ) = winners[i].call{value: prizeAmounts[i]}("");
                if (!success) {
                    distributionSuccess = false;
                }
                
                // Mint winner NFT if available
                if (address(nftContract) != address(0)) {
                    nftContract.mintWinnerNFT(winners[i], uint256(keccak256(abi.encodePacked(address(this)))), i + 1, prizeAmounts[i]);
                }
            }
        }
        
        // Mint participant NFTs for all
        if (address(nftContract) != address(0)) {
            for (uint256 i = 0; i < participants.length; i++) {
                nftContract.mintParticipantNFT(participants[i], uint256(keccak256(abi.encodePacked(address(this)))));
            }
        }
        
        require(distributionSuccess, "Prize distribution failed");
        emit PrizesDistributed(winners, prizeAmounts);
    }
    
    function setNFTContract(address _nftContract) external onlyCreator {
        nftContract = PulseNFT(_nftContract);
    }
    
    function getParticipantCount() external view returns (uint256) {
        return participants.length;
    }
    
    function getParticipantPosts(address _participant) external view returns (Post[] memory) {
        return userPosts[_participant];
    }
    
    function getLeaderboard() external view returns (address[] memory, uint256[] memory) {
        address[] memory leaderboardAddresses = new address[](participants.length);
        uint256[] memory scores = new uint256[](participants.length);
        
        for (uint256 i = 0; i < participants.length; i++) {
            leaderboardAddresses[i] = participants[i];
            scores[i] = participantInfo[participants[i]].totalScore;
        }
        
        // Simple bubble sort (optimize for production)
        for (uint256 i = 0; i < participants.length; i++) {
            for (uint256 j = i + 1; j < participants.length; j++) {
                if (scores[i] < scores[j]) {
                    // Swap addresses
                    (leaderboardAddresses[i], leaderboardAddresses[j]) = (leaderboardAddresses[j], leaderboardAddresses[i]);
                    // Swap scores
                    (scores[i], scores[j]) = (scores[j], scores[i]);
                }
            }
        }
        
        return (leaderboardAddresses, scores);
    }
    
    function _calculateWinners() internal {
        (address[] memory sortedParticipants, ) = getLeaderboard();
        
        for (uint256 i = 0; i < 3 && i < sortedParticipants.length; i++) {
            winners[i] = sortedParticipants[i];
        }
    }
    
    function getContestInfo() external view returns (
        string memory,
        uint256,
        uint256,
        uint256,
        uint256,
        ContestState,
        address
    ) {
        return (
            title,
            prizePool,
            startTime,
            endTime,
            participants.length,
            state,
            creator
        );
    }
    
    // Allow contract to receive funds (for additional prize pool)
    receive() external payable {
        prizePool += msg.value;
    }
}