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
    // This mapping stores the special maximum reputation for owners of specific NFTs
    mapping(address => int) public nftMaxReputation;
    
    uint public reputationCost = 0.01 ether;  // Reputation cost is 0.01 ether
    int public maxReputation = 3;

    event ReputationSet(address indexed sender, address indexed receiver, int reputation, string comment);
    event FundsWithdrawn(address owner, uint amount);
    
    constructor() {
        // Set the deployer as the initial owner and the initial moderator
        transferOwnership(msg.sender);
    }


    function setMaxReputation(int _maxReputation) public onlyOwner {
        maxReputation = _maxReputation;
    }

    // Store balances in wei for precision
    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function setReputation(address receiver, int reputation, string memory comment/*, address nftContractAddress, uint tokenId*/) public {


        // Check that the length of the string or hash is no more than 320 characters
        require(bytes(comment).length <= 320, "Comment string is too long");

        // Set the maximum reputation to the default value
        int currentMaxReputation = maxReputation;

        /*
        // If nftContractAddress is not the zero address, check for NFT ownership
        if (nftContractAddress != address(0)) {
            ERC721 nftContract = ERC721(nftContractAddress);

            // Check if the contract is valid and the token ID exists
            require(address(nftContract) != address(0), "Not a valid NFT contract");
            require(nftContract._exists(tokenId), "Token ID does not exist");

            // Check if the caller owns the token
            require(nftContract.ownerOf(tokenId) == msg.sender, "Must own the specified NFT");

            // If the caller owns the NFT, set the maximum reputation to the special value
            currentMaxReputation = nftMaxReputation[nftContractAddress];
        }
        */

        // Ensure the reputation is within bounds
        if (reputation > currentMaxReputation) {
            reputation = currentMaxReputation;
        } else if (reputation < -currentMaxReputation) {
            reputation = -currentMaxReputation;
        }

        uint cost = reputationCost * max(1, uint(abs(reputation)));  // Ensure cost is at least 1 reputation
        require(balances[msg.sender] >= cost, "Not enough funds");

        balances[msg.sender] -= cost;

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
        require(amountInWei <= address(this).balance, "Not enough balance");
        
        payable(owner()).transfer(amountInWei);
        
        emit FundsWithdrawn(owner(), amountInWei);
    }


    function abs(int x) private pure returns (uint) {
        return uint(x >= 0 ? x : -x);
    }

    // Maximum of two uint values
    function max(uint a, uint b) private pure returns (uint) {
        return a >= b ? a : b;
    }
}
