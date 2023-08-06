// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";


error ERSV2__REPUTATION_MAX_MUST_GREATER_ZERO();
error ERSV2__OWNER_EQUITY_CANNOT_EXCEED_100();
error ERSV2__COMMENT_LENGTH_TOO_LONG();
error ERSV2__NO_BALANCE_AVAILABLE();
error ERSV2__BALANCE_WITHDRAWAL_FAILED();
error ERSV2__REPUTATION_NOT_FOUND();


contract ReputationServiceMachine is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Mappings to store given and received reputations
    mapping(address => EnumerableSet.AddressSet) private givenReputation;
    mapping(address => EnumerableSet.AddressSet) private receivedReputation;

    struct ReputationData {
        uint128 packedReputationAndTimestamp; // Both reputation and timestamp are packed into a single 256-bit slot
        bytes32 commentHash;
    }

    mapping(address => mapping(address => ReputationData)) public reputationData; // Nested mapping for reputation data
    mapping(address => int) public totalReputation;
    mapping(address => uint) public balances; // Balances mapping for storing user balances
    

    uint public reputationPrice;
    uint public operatorEquity;
    uint public maxCommentBytes;
    int public maxReputation;


    event ReputationSet(address indexed sender, address indexed receiver, int reputation, string comment, uint timestamp);
    event ReputationPriceSet(uint newPrice);
    event MaxReputationSet(int newMaxReputation);
    event BalanceWithdrawn(address indexed receiver, uint amount);
    event OperatorEquitySet(uint newOperatorEquity);
    event MaxCommentBytesSet(uint newMaxCommentBytes);
    event ReputationDeleted(address indexed sender, address indexed receiver); // Event for deleting reputation
    
    
    // Constructor to initialize contract with default values
    constructor() {
        reputationPrice = 0.0 ether;
        operatorEquity = 100;
        maxCommentBytes = 320;
        maxReputation = 2;

        // Set the deployer as the initial owner
        transferOwnership(msg.sender);
    }


    // Function to set the price of reputation
    function setReputationPrice(uint _reputationPrice) public onlyOwner {
        reputationPrice = _reputationPrice;
        emit ReputationPriceSet(_reputationPrice);
    }

    // Function to set the maximum reputation value
    function setMaxReputation(int _maxReputation) public onlyOwner {
        if (_maxReputation <= 0) {
            revert ERSV2__REPUTATION_MAX_MUST_GREATER_ZERO();
        }
        maxReputation = _maxReputation;
        emit MaxReputationSet(_maxReputation);
    }


    // Function to set the operator's equity
    function setOperatorEquity(uint _operatorEquity) public onlyOwner {
        if (_operatorEquity > 100) {
            revert ERSV2__OWNER_EQUITY_CANNOT_EXCEED_100();
        }
        operatorEquity = _operatorEquity;
        emit OperatorEquitySet(_operatorEquity);
    }


    // Function to set the maximum comment bytes
    function setMaxCommentBytes(uint _maxCommentBytes) public onlyOwner {
        maxCommentBytes = _maxCommentBytes;
        emit MaxCommentBytesSet(_maxCommentBytes);
    }


    // Fallback function to deposit
    fallback() external payable {
        _depositInternal(msg.sender, msg.value);
    }


    // Receive function to deposit
    receive() external payable {
        _depositInternal(msg.sender, msg.value);
    }


    // Function to deposit ether
    function deposit() external payable {
        _depositInternal(msg.sender, msg.value);
    }


    // Internal function to handle deposit
    function _depositInternal(address _caller, uint _value) internal {
        balances[_caller] += _value;
    }


    // Function to set reputation
    function setReputation(address receiver, int reputation, string memory comment) public {
        setReputationInternal(receiver, reputation, comment, maxReputation);

        // Update the given and received reputation sets
        givenReputation[msg.sender].add(receiver);
        receivedReputation[receiver].add(msg.sender);
    }

    // Function to delete reputation
    function deleteReputation(address receiver) public {
        if (reputationData[msg.sender][receiver].packedReputationAndTimestamp == 0) {
            revert ERSV2__REPUTATION_NOT_FOUND();
        }

        ReputationData storage data = reputationData[msg.sender][receiver];
        int packedReputation = int64(uint64(data.packedReputationAndTimestamp >> 64));

        totalReputation[receiver] -= packedReputation;

        delete reputationData[msg.sender][receiver];

        givenReputation[msg.sender].remove(receiver);
        receivedReputation[receiver].remove(msg.sender);

        emit ReputationDeleted(msg.sender, receiver);
    }

    // Internal function to handle setting reputation
    function setReputationInternal(address receiver, int reputation, string memory comment, int currentMaxReputation) internal {
        if (bytes(comment).length > maxCommentBytes) {
            revert ERSV2__COMMENT_LENGTH_TOO_LONG();
        }

        if (reputation > currentMaxReputation) {
            reputation = currentMaxReputation;
        } else if (reputation < -currentMaxReputation) {
            reputation = -currentMaxReputation;
        }

        bytes32 commentHash = sha256(abi.encodePacked(comment));
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

        // Set the new packed reputation and timestamp data along with the comment hash
        reputationData[msg.sender][receiver] = ReputationData(packedReputationAndTimestamp, commentHash);

        totalReputation[receiver] += reputation;

        emit ReputationSet(msg.sender, receiver, reputation, comment, block.timestamp);
    }


    // Function to get reputation data
    function getReputationData(address sender, address receiver) public view returns (int reputation, uint timestamp, bytes32 commentHash) {
        ReputationData storage data = reputationData[sender][receiver];
        int packedReputation = int64(uint64(data.packedReputationAndTimestamp >> 64));
        uint packedTimestamp = uint64(data.packedReputationAndTimestamp);
        return (packedReputation, packedTimestamp, data.commentHash);
    }


    // Function to check if comment matches hash
    function isCommentMatchHash(address sender, address receiver, string memory comment) public view returns (bool) {
        ReputationData storage data = reputationData[sender][receiver];
        bytes32 storedHash = data.commentHash;
        bytes32 computedHash = sha256(abi.encodePacked(comment));

        return storedHash == computedHash;
    }


    // Function to withdraw balance
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


    // Function to get addresses that have given reputation to a user
    function getAddressesGivenReputationTo(address user) public view returns (address[] memory) {
        return givenReputation[user].values();
    }

    // Function to get addresses that have received reputation from a user
    function getAddressesReceivedReputationFrom(address user) public view returns (address[] memory) {
        return receivedReputation[user].values();
    }
}
