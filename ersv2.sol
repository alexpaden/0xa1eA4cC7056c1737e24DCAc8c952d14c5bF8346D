// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Reputation is Ownable {
    struct ReputationData {
        int reputation;
        string comment;
        uint timestamp;
    }

    mapping(address => mapping(address => ReputationData)) public reputationData; // nested mapping
    mapping(address => int) public totalReputation;
    mapping(address => uint) public balances;
    mapping(address => uint) public profits; // tracks accumulated profits for each address
    mapping(address => int) public nftMaxReputation;
    
    uint public reputationCost = 10000000000000000;  // Reputation cost is initially 0.01 ether (in wei)
    uint public ownerBalance= 0; // tracks the owner's share of the profits
    uint public ownerPercent = 75; // tracks the percentage of profits that go to the owner, initially set to 75%
    int public maxReputation = 2;

    event ReputationSet(address indexed sender, address indexed receiver, int reputation, string comment, uint timestamp);
    event FundsWithdrawn(address owner, uint amount);
    event ReputationCostSet(uint newCost);
    event MaxReputationSet(int newMaxReputation);
    event ProfitShared(address indexed receiver, uint amount);
    event ProfitsWithdrawn(address indexed receiver, uint amount);
    event OwnerPercentSet(uint newOwnerPercent);
    event MaxReputationChanged(int256 newMaxReputation);

    
    constructor() {
        // Set the deployer as the initial owner
        transferOwnership(msg.sender);
    }

    function setReputationCost(uint _reputationCost) public onlyOwner {
        reputationCost = _reputationCost;
        emit ReputationCostSet(_reputationCost);
    }

    function setMaxReputation(int _maxReputation) public onlyOwner {
        maxReputation = _maxReputation;
        emit MaxReputationSet(_maxReputation);
    }

    function setNftMaxReputation(address nftContractAddress, int _nftMaxReputation) public onlyOwner {
        nftMaxReputation[nftContractAddress] = _nftMaxReputation;
        emit MaxReputationChanged(_nftMaxReputation); // Emit the event with the new value
    }


    function setOwnerPercent(uint _ownerPercent) public onlyOwner {
        require(_ownerPercent <= 100, "Owner percent cannot exceed 100");
        ownerPercent = _ownerPercent;
        emit OwnerPercentSet(_ownerPercent);
    }

    // Store balances in wei for precision
    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function setReputation(address receiver, int reputation, string memory comment, address nftContractAddress, uint tokenId) public {
        int currentMaxReputation = getMaxReputation(nftContractAddress, tokenId);
        setReputationInternal(receiver, reputation, comment, currentMaxReputation);
    }

    function setReputation(address receiver, int reputation, string memory comment) public {
        setReputationInternal(receiver, reputation, comment, maxReputation);
    }

    function setReputationInternal(address receiver, int reputation, string memory comment, int currentMaxReputation) internal {
        // Check that the length of the string or hash is no more than 320 characters
        require(bytes(comment).length <= 320, "Comment string is too long");

        // Ensure the reputation is within bounds
        if (reputation > currentMaxReputation) {
            reputation = currentMaxReputation;
        } else if (reputation < -currentMaxReputation) {
            reputation = -currentMaxReputation;
        }

        require(balances[msg.sender] >= reputationCost, "Not enough funds");
        balances[msg.sender] -= reputationCost;

        uint reputationCostScaled = reputationCost * 100;
        uint ownerShare = (reputationCostScaled * ownerPercent) / 10000;
        ownerBalance += ownerShare;
        profits[receiver] += reputationCost - ownerShare;

        // If the sender has already given a reputation to the receiver, deduct it from the total
        if(reputationData[msg.sender][receiver].reputation != 0) {
            totalReputation[receiver] -= reputationData[msg.sender][receiver].reputation;
        }

        // Set the new reputation data
        reputationData[msg.sender][receiver] = ReputationData(reputation, comment, block.timestamp);

        // Add the new reputation to the total
        totalReputation[receiver] += reputation;

        emit ReputationSet(msg.sender, receiver, reputation, comment, block.timestamp);
        emit ProfitShared(receiver, reputationCost - ownerShare);
    }

    function getMaxReputation(address nftContractAddress, uint tokenId) internal view returns (int) {
        if (nftContractAddress != address(0)) {
            ERC721 nftContract = ERC721(nftContractAddress);
            require(nftContract.ownerOf(tokenId) == msg.sender, "Must own the specified NFT");
            return nftMaxReputation[nftContractAddress];
        }
        return maxReputation;
    }

    // Retrieve the value and comment for a reputation between the sender and receiver addresses
    function getReputationData(address sender, address receiver) public view returns (ReputationData memory) {
        return reputationData[sender][receiver];
    }

    // Input in wei
    function withdrawFunds(uint amountInWei) public onlyOwner {
        require(amountInWei <= ownerBalance, "Not enough balance in owner's share");
            
        // Make state change before external call
        ownerBalance -= amountInWei;

        // External call
        payable(owner()).transfer(amountInWei);
            
        emit FundsWithdrawn(owner(), amountInWei);
    }


    // Allow users to withdraw their share of the profits
    function withdrawProfits() public {
        uint profit = profits[msg.sender];
        require(profit > 0, "No profits available for withdrawal");

        // Reset user's profit before sending to prevent re-entrancy attacks
        profits[msg.sender] = 0;
        
        // Use the 'call' function to make the transfer and check if it was successful
        (bool success, ) = msg.sender.call{value: profit}("");
        require(success, "Transfer failed");

        emit ProfitsWithdrawn(msg.sender, profit);
    }

}
