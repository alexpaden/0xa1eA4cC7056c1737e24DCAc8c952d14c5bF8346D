// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Reputation is Ownable {
    struct ReputationData {
        int reputation;
        string comment;
        uint timestamp;
    }

    mapping(address => mapping(address => ReputationData)) public reputationData; // nested mapping
    mapping(address => int) public totalReputation;
    mapping(address => uint) public balances;
    // This mapping stores the special maximum reputation for owners of specific NFTs
    
    uint public reputationCost = 10000000000000000;  // Reputation cost is initially 0.01 ether (in wei)
    int public maxReputation = 2;

    event ReputationSet(address indexed sender, address indexed receiver, int reputation, string comment, uint timestamp);
    event FundsWithdrawn(address owner, uint amount);
    event ReputationCostSet(uint newCost);
    event MaxReputationSet(int newMaxReputation);
    
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

        // If the sender has already given a reputation to the receiver, deduct it from the total
        if(reputationData[msg.sender][receiver].reputation != 0) {
            totalReputation[receiver] -= reputationData[msg.sender][receiver].reputation;
        }

        // Set the new reputation data
        reputationData[msg.sender][receiver] = ReputationData(reputation, comment, block.timestamp);


        // Add the new reputation to the total
        totalReputation[receiver] += reputation;

        emit ReputationSet(msg.sender, receiver, reputation, comment, block.timestamp);
    }

    // Retrieve the value and comment for a reputation between the sender and receiver addresses
    function getReputationData(address sender, address receiver) public view returns (ReputationData memory) {
        return reputationData[sender][receiver];
    }

    // Input in wei
    function withdrawFunds(uint amountInWei) public onlyOwner {
        require(amountInWei <= address(this).balance, "Not enough balance");
        
        payable(owner()).transfer(amountInWei);
        
        emit FundsWithdrawn(owner(), amountInWei);
    }
}
