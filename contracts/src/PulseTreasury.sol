// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PulseTreasury is ReentrancyGuard {
    address public owner;
    uint256 public totalPlatformFees;
    uint256 public totalPrizesDistributed;
    
    mapping(address => uint256) public contestBalances;
    mapping(address => uint256) public platformEarnings;
    mapping(address => uint256) public tokenBalances;
    
    event FundsDeposited(address indexed contest, uint256 amount);
    event PlatformFeesWithdrawn(address indexed recipient, uint256 amount);
    event EmergencyWithdraw(address indexed token, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    function depositContestFunds(address _contest) external payable {
        require(_contest != address(0), "Invalid contest address");
        require(msg.value > 0, "Must deposit more than 0");
        
        contestBalances[_contest] += msg.value;
        
        emit FundsDeposited(_contest, msg.value);
    }
    
    function depositTokenFunds(address _token, address _contest, uint256 _amount) external {
        require(_contest != address(0), "Invalid contest address");
        require(_amount > 0, "Must deposit more than 0");
        
        IERC20 token = IERC20(_token);
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        
        contestBalances[_contest] += _amount;
        tokenBalances[_token] += _amount;
        
        emit FundsDeposited(_contest, _amount);
    }
    
    function withdrawPlatformFees(address _token) external onlyOwner nonReentrant {
        uint256 amount = platformEarnings[_token];
        require(amount > 0, "No fees to withdraw");
        
        platformEarnings[_token] = 0;
        totalPlatformFees += amount;
        
        if (_token == address(0)) {
            (bool success, ) = owner.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20 token = IERC20(_token);
            require(token.transfer(owner, amount), "Token transfer failed");
        }
        
        emit PlatformFeesWithdrawn(owner, amount);
    }
    
    function recordPrizeDistribution(uint256 _amount) external {
        totalPrizesDistributed += _amount;
    }
    
    function recordPlatformFee(address _token, uint256 _amount) external {
        platformEarnings[_token] += _amount;
    }
    
    function calculatePrizeDistribution(uint256 _totalPool, uint256[3] memory _distribution) 
        public 
        pure 
        returns (uint256[3] memory) 
    {
        return [
            (_totalPool * _distribution[0]) / 10000,
            (_totalPool * _distribution[1]) / 10000,
            (_totalPool * _distribution[2]) / 10000
        ];
    }
    
    function getTreasuryStats() external view returns (
        uint256 totalFees,
        uint256 totalPrizes,
        uint256 ethBalance,
        uint256 contestCount
    ) {
        return (
            totalPlatformFees,
            totalPrizesDistributed,
            address(this).balance,
            // This would need to be tracked separately
            0
        );
    }
    
    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
        if (_token == address(0)) {
            (bool success, ) = owner.call{value: _amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20 token = IERC20(_token);
            require(token.transfer(owner, _amount), "Token transfer failed");
        }
        
        emit EmergencyWithdraw(_token, _amount);
    }
    
    receive() external payable {
        // Accept ETH deposits
    }
}