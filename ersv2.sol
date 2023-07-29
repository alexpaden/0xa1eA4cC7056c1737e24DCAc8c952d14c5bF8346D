// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Use custom errors to reduce gas! e.g.
error ERSV2__REPUTATION_COST_MUST_BE_NON_ZERO();

contract Reputation is Ownable {
    struct ReputationData {
        int64 reputation; // since you edit reputation and timestamp at the same time, you can do struct packing
        uint64 timestamp; // saves gas. EVM has 256 bit slots. So this way both reputation and timestamp can fit in one slot.
        string comment; // consider hashing the comment and just storing that in the contract to save gas. OR at least consider storing in the `bytes` form. 
    }

    mapping(address => mapping(address => ReputationData)) public reputationData; // nested mapping
    mapping(address => int) public totalReputation;
    mapping(address => uint) public balances;
    mapping(address => uint) public profits; // tracks accumulated profits for each address
    mapping(address => uint) public nftMaxReputation; // in `setNftMaxReputation` you seem to check it is greater than 0
    

    uint public reputationCost = 0.01 ether;  // Reputation cost is initially 0.01 ether (in wei)
    uint public ownerBalance= 0; // tracks the owner's share of the profits
    // ^ if you care for gas, you don't need this. Store it in `profits[owner] mapping` and you can use your withdrawProfits() method
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
        // idk much about your deploy script but to save gas you could set 
        // reputationCost
        // maxReputation
        // nftMaxReputation
        // ownerPercent
        // this way you don't need to set all of them at deploy time. 
        // But again useful only if you want to set them at deploy time

        // Set the deployer as the initial owner
        transferOwnership(msg.sender);
    }


    function setReputationCost(uint _reputationCost) public onlyOwner {
        //require(_reputationCost > 0, "Reputation cost cannot be zero");
        if (_reputationCost == 0) {
            revert ERSV2__REPUTATION_COST_MUST_BE_NON_ZERO();
        } // using custom errors to reduce gas cost.

        if (_reputationCost )
        reputationCost = _reputationCost;
        emit ReputationCostSet(_reputationCost);
    }

    function setMaxReputation(int _maxReputation) public onlyOwner {
        require(_maxReputation > 0, "Max reputation cannot be zero");
        // ^ use custom errors here too!
        maxReputation = _maxReputation;
        emit MaxReputationSet(_maxReputation);
    }


    function setNftMaxReputation(address nftContractAddress, int _nftMaxReputation) public onlyOwner {
        // if you are checking _nftMaxReputation > 0, why this is an `int` and not  `uint`.
        require(_nftMaxReputation > 0, "Max NFT reputation cannot be zero");
        // ^ use custom errors here too!
        nftMaxReputation[nftContractAddress] = _nftMaxReputation;
        emit MaxReputationChanged(_nftMaxReputation); // Emit the event with the new value
    }


    function setOwnerPercent(uint _ownerPercent) public onlyOwner {
        require(_ownerPercent <= 100, "Owner percent cannot exceed 100");
        // ^ use custom errors here too!
        ownerPercent = _ownerPercent;
        emit OwnerPercentSet(_ownerPercent);
    }

    // this is a fallback function. It is triggered if someone were to send eth to your contract without calling a method 
    // (OR if calling the wrong method). ANyway, having this improves UX - 
    // user doesn't need to call `deposit` and can simplu jusy send eth
    function () public payable {
        _depositInternal(msg.sender, msg.value);
    }


    function deposit() external payable {
        _depositInternal(msg.sender, msg.value);
    }

    // Store balances in wei for precision
    function _depositInternal(address _caller, uint _value) internal {
        balances[_caller] += _value;
    }

    function setReputation(address receiver, int reputation, string memory comment, address nftContractAddress, uint tokenId) public {
        int currentMaxReputation = getMaxReputation(nftContractAddress, tokenId);
        setReputationInternal(receiver, reputation, comment, currentMaxReputation);
    }


    function setReputation(address receiver, int reputation, string memory comment) public {
        setReputationInternal(receiver, reputation, comment, maxReputation);
    }


    function setReputationInternal(address receiver, int reputation, string memory comment, int currentMaxReputation) internal {
        require(bytes(comment).length <= 320, "Comment string is too long");
        require(bytes(comment).length > 0, "Comment cannot be empty");

        // Ensure the reputation is within bounds
        if (reputation > currentMaxReputation) {
            reputation = currentMaxReputation;
        } else if (reputation < -currentMaxReputation) {
            reputation = -currentMaxReputation;
        }

        // require(balances[msg.sender] >= reputationCost, "Not enough funds");
        // ^ you don't need this check -> if balances is less, it would underflow. in solidity v0.8, underflow throws an error. 
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
            // this method is only called in setReputation() which is `onlyOwner`. So only owner can be msg.sender. So only owner's NFTs can have a reputation? Is this intended?
            // Btw this method can be made external. So need to keep it internal
            // Btw#2, internal methods is solidity typically start with an underscore e.g. `getMaxReputation()`

            require(nftContract.ownerOf(tokenId) == msg.sender, "Must own the specified NFT");
            return nftMaxReputation[nftContractAddress];
        }
        return maxReputation;
    }

    // Retrieve the value and comment for a reputation between the sender and receiver addresses
    function getReputationData(address sender, address receiver) public view returns (ReputationData memory) {
        return reputationData[sender][receiver];
    }


    function withdrawOwnerProfits() public onlyOwner {
        uint profit = ownerBalance;
        require(profit > 0, "No profits available for withdrawal");

        ownerBalance = 0;

        (bool success, ) = msg.sender.call{value: profit}("");
        require(success, "Transfer failed");

        emit ProfitsWithdrawn(msg.sender, profit);
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
