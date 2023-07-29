// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


error ERSV2__REPUTATION_MAX_MUST_GREATER_ZERO();
error ERSV2__OWNER_EQUITY_CANNOT_EXCEED_100();
error ERSV2__COMMENT_LENGTH_TOO_LONG();
error ERSV2__NO_BALANCE_AVAILABLE();
error ERSV2__BALANCE_WITHDRAWAL_FAILED();


contract ReputationServiceMachine is Ownable {
    struct ReputationData {
        uint128 packedReputationAndTimestamp; // Both reputation and timestamp are packed into a single 256-bit slot
        string comment;
    }

    mapping(address => mapping(address => ReputationData)) public reputationData; // nested mapping
    mapping(address => int) public totalReputation;
    mapping(address => uint) public balances;
    

    uint public reputationPrice;
    uint public operatorEquity;
    uint public maxCommentBytes;
    int public maxReputation;


    event ReputationSet(address indexed sender, address indexed receiver, int reputation, string comment, uint timestamp);
    event ReputationPriceSet(uint newPrice);
    event MaxReputationSet(int newMaxReputation);
    event BalanceWithdrawn(address indexed receiver, uint amount);
    event OperatorEquitySet(uint newOperatorEquity);
    
    
    constructor() {
        reputationPrice = 0.01 ether;
        operatorEquity = 100;
        maxCommentBytes = 320;
        maxReputation = 2;

        // Set the deployer as the initial owner
        transferOwnership(msg.sender);
    }


    function setReputationPrice(uint _reputationPrice) public onlyOwner {
        reputationPrice = _reputationPrice;
        emit ReputationPriceSet(_reputationPrice);
    }

    function setMaxReputation(int _maxReputation) public onlyOwner {
        if (_maxReputation <= 0) {
            revert ERSV2__REPUTATION_MAX_MUST_GREATER_ZERO();
        }
        maxReputation = _maxReputation;
        emit MaxReputationSet(_maxReputation);
    }


    function setOperatorEquity(uint _operatorEquity) public onlyOwner {
        if (_operatorEquity > 100) {
            revert ERSV2__OWNER_EQUITY_CANNOT_EXCEED_100();
        }
        operatorEquity = _operatorEquity;
        emit OperatorEquitySet(_operatorEquity);
    }


    fallback() external payable {
        _depositInternal(msg.sender, msg.value);
    }


    receive() external payable {
        _depositInternal(msg.sender, msg.value);
    }


    function deposit() external payable {
        _depositInternal(msg.sender, msg.value);
    }


    function _depositInternal(address _caller, uint _value) internal {
        balances[_caller] += _value;
    }


    function setReputation(address receiver, int reputation, string memory comment) public {
        setReputationInternal(receiver, reputation, comment, maxReputation);
    }


    function setReputationInternal(address receiver, int reputation, string memory comment, int currentMaxReputation) internal {
        if (bytes(comment).length > maxCommentBytes) {
            revert ERSV2__COMMENT_LENGTH_TOO_LONG();
        }

        if (reputation > currentMaxReputation) {
            reputation = currentMaxReputation;
        } else if (reputation < -currentMaxReputation) {
            reputation = -currentMaxReputation;
        }

        balances[msg.sender] -= reputationPrice;

        // net receiver revenue calculation
        uint reputationPriceScaled = reputationPrice * 100;
        uint ownerRevenue = (reputationPriceScaled * operatorEquity) / 10000;
        balances[owner()] += ownerRevenue;
        balances[receiver] += reputationPrice - ownerRevenue;

        // If the sender has already given a reputation to the receiver, deduct it from the total
        if (reputationData[msg.sender][receiver].packedReputationAndTimestamp != 0) {
            int previousReputation = int64(uint64(reputationData[msg.sender][receiver].packedReputationAndTimestamp >> 64));
            totalReputation[receiver] -= previousReputation;
        }

        // Pack the reputation and timestamp together into the 128-bit field
        uint128 packedReputationAndTimestamp = uint128(uint256(reputation)) << 64 | uint64(block.timestamp);


        // Set the new packed reputation and timestamp data
        reputationData[msg.sender][receiver] = ReputationData(packedReputationAndTimestamp, comment);

        totalReputation[receiver] += reputation;

        emit ReputationSet(msg.sender, receiver, reputation, comment, block.timestamp);
    }


    // Retrieve the value and comment for a reputation between the sender and receiver addresses
    function getReputationData(address sender, address receiver) public view returns (int reputation, uint timestamp, string memory comment) {
        ReputationData storage data = reputationData[sender][receiver];
        int packedReputation = int64(uint64(data.packedReputationAndTimestamp >> 64));
        uint packedTimestamp = uint64(data.packedReputationAndTimestamp);
        return (packedReputation, packedTimestamp, data.comment);
    }



    function withdrawBalance() public {
        uint balance = balances[msg.sender];

        if (balance == 0) {
            revert ERSV2__NO_BALANCE_AVAILABLE();
        }

        balances[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: balance}("");
        if (!success) {
            revert ERSV2__BALANCE_WITHDRAWAL_FAILED();
        }

        emit BalanceWithdrawn(msg.sender, balance);
    }


}