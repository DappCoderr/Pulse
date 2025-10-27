// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PulseContest.sol";

contract PulseFactory {
    address public owner;
    uint256 public contestCount;
    address[] public allContests;
    mapping(address => bool) public isContest;
    mapping(address => address[]) public userContests;
    
    uint256 public platformFee = 500; // 5%
    address public feeRecipient;
    
    event ContestCreated(
        address indexed contestAddress,
        address indexed creator,
        string title,
        uint256 prizePool,
        uint256 duration
    );
    
    event PlatformFeeUpdated(uint256 newFee);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }
    
    constructor(address _feeRecipient) {
        owner = msg.sender;
        feeRecipient = _feeRecipient;
    }
    
    function createContest(
        string memory _title,
        uint256 _duration,
        string memory _rules,
        address _rewardToken
    ) external payable returns (address) {
        require(msg.value >= 50, "Prize pool must be greater or equeal to 50 Flow");
        require(_duration >= 1 days && _duration <= 30 days, "Duration must be between 1-30 days");
        
        uint256 platformFeeAmount = (msg.value * platformFee) / 10000;
        uint256 contestPrizePool = msg.value - platformFeeAmount;
        
        // Transfer platform fee
        (bool feeSuccess, ) = feeRecipient.call{value: platformFeeAmount}("");
        require(feeSuccess, "Fee transfer failed");
        
        PulseContest newContest = new PulseContest{value: contestPrizePool}(
            _title,
            contestPrizePool,
            _duration,
            _rules,
            _rewardToken,
            msg.sender
        );
        
        address contestAddress = address(newContest);
        allContests.push(contestAddress);
        isContest[contestAddress] = true;
        userContests[msg.sender].push(contestAddress);
        contestCount++;
        
        emit ContestCreated(contestAddress, msg.sender, _title, contestPrizePool, _duration);
        return contestAddress;
    }
    
    function setPlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000, "Fee cannot exceed 10%");
        platformFee = _newFee;
        emit PlatformFeeUpdated(_newFee);
    }
    
    function setFeeRecipient(address _newRecipient) external onlyOwner {
        require(_newRecipient != address(0), "Invalid address");
        feeRecipient = _newRecipient;
    }
    
    function getAllContests() external view returns (address[] memory) {
        return allContests;
    }
    
    function getUserContests(address _user) external view returns (address[] memory) {
        return userContests[_user];
    }
    
    function getActiveContests() external view returns (address[] memory) {
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < allContests.length; i++) {
            if (PulseContest(allContests[i]).state() == PulseContest.ContestState.ACTIVE) {
                activeCount++;
            }
        }
        
        address[] memory activeContests = new address[](activeCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < allContests.length; i++) {
            if (PulseContest(allContests[i]).state() == PulseContest.ContestState.ACTIVE) {
                activeContests[currentIndex] = allContests[i];
                currentIndex++;
            }
        }
        
        return activeContests;
    }
}