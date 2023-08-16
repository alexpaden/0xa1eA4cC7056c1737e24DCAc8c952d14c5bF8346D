// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Reputation is Ownable {
    struct ReputationData {
        int reputation;
        string comment;
    }

    mapping(address => mapping(address => ReputationData)) public reputationData; // nested mapping
    mapping(address => int) public totalReputation;
    mapping(address => uint) public balances;
    mapping(address => uint) public profits; // tracks accumulated profits for each address
    uint public reputationCost = 10000000000000000;  // Reputation cost is initially 0.01 ether (in wei)
    uint public ownerBalance; // tracks the owner's share of the profits
    uint public ownerPercent = 75; // tracks the percentage of profits that go to the owner, initially set to 75%
    int public maxReputation = 2;

    event ReputationSet(address indexed sender, address indexed receiver, int reputation, string comment);
    event FundsWithdrawn(address owner, uint amount);
    
    constructor() {
        // Set the deployer as the initial owner
        transferOwnership(msg.sender);
    }

    function setReputationCost(uint _reputationCost) public onlyOwner {
        reputationCost = _reputationCost;
    }

    function setOwnerPercent(uint _ownerPercent) public onlyOwner {
        require(_ownerPercent <= 100, "Owner percent cannot exceed 100");
        ownerPercent = _ownerPercent;
    }

    function setMaxReputation(int _maxReputation) public onlyOwner {
        maxReputation = _maxReputation;
    }

    // Store balances in wei for precision
    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function setReputation(address receiver, int reputation, string memory comment) public {

        // Check that the length of the string or hash is no more than 320 characters
        require(bytes(comment).length <= 320, "Comment string is too long");

        // Set the maximum reputation to the default value
        int currentMaxReputation = maxReputation;

        // Ensure the reputation is within bounds
        if (reputation > currentMaxReputation) {
            reputation = currentMaxReputation;
        } else if (reputation < -currentMaxReputation) {
            reputation = -currentMaxReputation;
        }

        require(balances[msg.sender] >= reputationCost, "Not enough funds");

        balances[msg.sender] -= reputationCost;
        uint ownerShare = (reputationCost * ownerPercent) / 100;
        ownerBalance += ownerShare;
        profits[receiver] += reputationCost - ownerShare;

        // If the sender has already given a reputation to the receiver, deduct it from the total
        if(reputationData[msg.sender][receiver].reputation != 0) {
            totalReputation[receiver] -= reputationData[msg.sender][receiver].reputation;
        }

        // Set the new reputation data
        reputationData[msg.sender][receiver] = ReputationData(reputation, comment);

        // Add the new reputation to the total
        totalReputation[receiver] += reputation;

        emit ReputationSet(msg.sender, receiver, reputation, comment);
    }

    // Retrieve the value and comment for a reputation between the sender and receiver addresses
    function getReputationData(address sender, address receiver) public view returns (ReputationData memory) {
        return reputationData[sender][receiver];
    }

    // Input in wei
    function withdrawFunds(uint amountInWei) public onlyOwner {
        require(amountInWei <= ownerBalance, "Not enough balance in owner's share");
        
        payable(owner()).transfer(amountInWei);
        ownerBalance -= amountInWei;
        
        emit FundsWithdrawn(owner(), amountInWei);
    }
}