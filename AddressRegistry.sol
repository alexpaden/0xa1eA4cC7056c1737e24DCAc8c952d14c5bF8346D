// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract AddressRegistry is Ownable {
    using ECDSA for bytes32;

    uint256 public registrationFee;
    uint256 public maxRSIDsPerAddress;
    uint256 public lastRSID;
    uint256 public maxContractsTagged;

    struct User {
        address[] addresses;
        mapping(address => bool) isAssociated;
        mapping(address => bool) isDelegated;
        bool exists;
    }

    struct RSIDSettings {
        address delegateAddress;
        bool exists;
    }

    mapping(uint256 => User) private users;
    mapping(address => uint256[]) private rsidOfAddress;
    mapping(uint256 => RSIDSettings) private rsidSettings;
    mapping(bytes32 => address[]) private taggedContracts;

    error ERSID_NOT_FOUND();
    error ERSID_ALREADY_ASSOCIATED();
    error EINDEX_OUT_OF_RANGE();
    error ERSID_NOT_EXIST();
    error ERSID_EXCEEDED_MAX_RSIDS();
    error ERSID_NOT_AUTHORIZED();
    error ERSID_DELEGATED_ADDRESS_ALREADY_EXISTS();
    error ERSID_DELEGATED_ADDRESS_NOT_FOUND();
    error ECONTRACT_ALREADY_TAGGED();
    error ECONTRACTS_EXCEEDED_MAX();
    error ECONTRACT_NOT_FOUND();
    error E_ONLY_ASSOCIATED_CAN_DELEGATE();
    error E_ONLY_ASSOCIATED_OR_DELEGATE_CAN_REMOVE_OTHER_ADDRESSES();
    error E_ONLY_DELEGATE_CAN_REMOVE_OTHER_ADDRESSES();
    error E_ONLY_CURRENT_DELEGATE_CAN_CHANGE();
    error E_ONLY_ASSOCIATED_CAN_REMOVE_DELEGATE();

    event RSIDCreated(uint256 rsid, address indexed owner);
    event AddressesUpdated(uint256 rsid, address[] addresses);
    event DelegatedAddressAdded(uint256 rsid, address indexed delegatedAddress);
    event DelegatedAddressRemoved(uint256 rsid, address indexed delegatedAddress);
    event TaggedContractAdded(uint256 rsid, address indexed contractAddress);
    event RegistrationFeeChanged(uint256 newFee);
    event MaxRSIDsPerAddressChanged(uint256 newMax);
    event MaxContractsTaggedChanged(uint256 newMax);
    event TaggedContractRemoved(uint256 rsid, address indexed contractAddress);
    event Error(string message);

    constructor() {
        registrationFee = 0 ether;
        maxRSIDsPerAddress = 1;
        lastRSID = 0;
        maxContractsTagged = 5;
    }

    function addTaggedContracts(uint256 rsid, address[] memory contractAddresses) public {
        if (!rsidSettings[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        if (!users[rsid].isAssociated[msg.sender] && !users[rsid].isDelegated[msg.sender]) {
            revert ERSID_NOT_AUTHORIZED();
        }

        bytes32 key = keccak256(abi.encodePacked(rsid));
        if (taggedContracts[key].length + contractAddresses.length > maxContractsTagged) {
            revert ECONTRACTS_EXCEEDED_MAX();
        }

        for (uint i = 0; i < contractAddresses.length; i++) {
            for (uint j = 0; j < taggedContracts[key].length; j++) {
                if (contractAddresses[i] == taggedContracts[key][j]) {
                    revert ECONTRACT_ALREADY_TAGGED();
                }
            }
            taggedContracts[key].push(contractAddresses[i]);
            emit TaggedContractAdded(rsid, contractAddresses[i]);
        }
    }

    function removeTaggedContract(uint256 rsid, address contractAddress) public {
        if (!rsidSettings[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        if (!users[rsid].isAssociated[msg.sender] && !users[rsid].isDelegated[msg.sender]) {
            revert ERSID_NOT_AUTHORIZED();
        }

        bytes32 key = keccak256(abi.encodePacked(rsid));
        uint256 index = taggedContracts[key].length;

        for (uint i = 0; i < taggedContracts[key].length; i++) {
            if (taggedContracts[key][i] == contractAddress) {
                index = i;
                break;
            }
        }

        if (index == taggedContracts[key].length) {
            revert ECONTRACT_NOT_FOUND();
        }

        taggedContracts[key][index] = taggedContracts[key][taggedContracts[key].length - 1];
        taggedContracts[key].pop();

        emit TaggedContractRemoved(rsid, contractAddress);
    }

    function getTaggedContracts(uint256 rsid) public view returns (address[] memory) {
        if (!rsidSettings[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        bytes32 key = keccak256(abi.encodePacked(rsid));
        return taggedContracts[key];
    }

    function setMaxContractsTagged(uint256 newMax) public onlyOwner {
        maxContractsTagged = newMax;
        emit MaxContractsTaggedChanged(newMax);
    }

    function _generateRSID() internal returns (uint256) {
        lastRSID++;
        return lastRSID;
    }

    function createRSID() public payable {
        if (msg.value < registrationFee) {
            emit Error("Insufficient registration fee");
            return;
        }
        if (rsidOfAddress[msg.sender].length >= maxRSIDsPerAddress) {
            revert ERSID_EXCEEDED_MAX_RSIDS();
        }

        uint256 rsid = _generateRSID();
        users[rsid].addresses.push(msg.sender);
        users[rsid].isAssociated[msg.sender] = true;
        rsidOfAddress[msg.sender].push(rsid);
        users[rsid].exists = true;
        rsidSettings[rsid].exists = true;

        emit RSIDCreated(rsid, msg.sender);
    }

    function getAddresses(uint256 rsid) public view returns (address[] memory) {
        if (!rsidSettings[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        return users[rsid].addresses;
    }

    function isAddressDelegated(uint256 rsid, address anyAddress) public view returns (bool) {
        if (!rsidSettings[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        return users[rsid].isDelegated[anyAddress];
    }

    function getRSIDOfAddress(address anyAddress) public view returns (uint256) {
        uint256 rsidCount = rsidOfAddress[anyAddress].length;
        if (rsidCount == 0) {
            revert ERSID_NOT_FOUND();
        }
        return rsidOfAddress[anyAddress][0];
    }

    function getRSIDOfAddress(address anyAddress, uint256 index) public view returns (uint256) {
        uint256 rsidCount = rsidOfAddress[anyAddress].length;
        if (index >= rsidCount) {
            revert EINDEX_OUT_OF_RANGE();
        }
        return rsidOfAddress[anyAddress][index];
    }

    function updateAddresses(uint256 rsid, address[] memory newAddresses) public {
        if (!rsidSettings[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }

        uint256 oldRSID = getRSIDOfAddress(msg.sender);
        if (oldRSID != 0 && oldRSID != rsid) {
            for (uint256 i = 0; i < users[oldRSID].addresses.length; i++) {
                if (users[oldRSID].addresses[i] == msg.sender) {
                    users[oldRSID].addresses[i] = users[oldRSID].addresses[users[oldRSID].addresses.length - 1];
                    users[oldRSID].addresses.pop();
                    break;
                }
            }
        }

        for (uint256 i = 0; i < newAddresses.length; i++) {
            if (rsidOfAddress[newAddresses[i]].length >= maxRSIDsPerAddress) {
                revert ERSID_EXCEEDED_MAX_RSIDS();
            }
            if (users[rsid].isAssociated[newAddresses[i]]) {
                revert ERSID_ALREADY_ASSOCIATED();
            }
            users[rsid].addresses.push(newAddresses[i]);
            users[rsid].isAssociated[newAddresses[i]] = true;
            rsidOfAddress[newAddresses[i]].push(rsid);
        }

        emit AddressesUpdated(rsid, newAddresses);
    }

    function addDelegatedAddress(uint256 rsid, address delegatedAddress) public {
        if (!rsidSettings[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        if (rsidSettings[rsid].delegateAddress != address(0)) {
            revert ERSID_DELEGATED_ADDRESS_ALREADY_EXISTS();
        }

        bool isRSIDOwner = false;
        for (uint i = 0; i < users[rsid].addresses.length; i++) {
            if (users[rsid].addresses[i] == msg.sender) {
                isRSIDOwner = true;
                break;
            }
        }

        if (!isRSIDOwner) {
            revert E_ONLY_ASSOCIATED_CAN_DELEGATE();
        }

        rsidSettings[rsid].delegateAddress = delegatedAddress;
        users[rsid].isDelegated[delegatedAddress] = true;

        emit DelegatedAddressAdded(rsid, delegatedAddress);
    }

    function changeDelegatedAddress(uint256 rsid, address newDelegatedAddress) public {
        if (!rsidSettings[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }

        if (rsidSettings[rsid].delegateAddress != msg.sender) {
            revert E_ONLY_CURRENT_DELEGATE_CAN_CHANGE();
        }

        users[rsid].isDelegated[rsidSettings[rsid].delegateAddress] = false;
        rsidSettings[rsid].delegateAddress = newDelegatedAddress;
        users[rsid].isDelegated[newDelegatedAddress] = true;

        emit DelegatedAddressAdded(rsid, newDelegatedAddress);
    }

    function removeDelegatedAddress(uint256 rsid, address delegatedAddress) public {
        if (!rsidSettings[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        if (!users[rsid].isDelegated[delegatedAddress]) {
            revert ERSID_DELEGATED_ADDRESS_NOT_FOUND();
        }

        if (!users[rsid].isAssociated[msg.sender]) {
            revert E_ONLY_ASSOCIATED_CAN_REMOVE_DELEGATE();
        }
        
        users[rsid].isDelegated[delegatedAddress] = false;
        rsidSettings[rsid].delegateAddress = address(0);

        emit DelegatedAddressRemoved(rsid, delegatedAddress);
    }

    function removeSelfFromRSID(uint256 rsid) public {
        if (!rsidSettings[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        if (!users[rsid].isAssociated[msg.sender]) {
            revert ERSID_NOT_AUTHORIZED();
        }

        for (uint i = 0; i < users[rsid].addresses.length; i++) {
            if (users[rsid].addresses[i] == msg.sender) {
                users[rsid].addresses[i] = users[rsid].addresses[users[rsid].addresses.length - 1];
                users[rsid].addresses.pop();
                break;
            }
        }
        
        for (uint i = 0; i < rsidOfAddress[msg.sender].length; i++) {
            if (rsidOfAddress[msg.sender][i] == rsid) {
                rsidOfAddress[msg.sender][i] = rsidOfAddress[msg.sender][rsidOfAddress[msg.sender].length - 1];
                rsidOfAddress[msg.sender].pop();
                break;
            }
        }

        users[rsid].isAssociated[msg.sender] = false;
    }

    function removeAssociatedAddressFromRSID(uint256 rsid, address associatedAddress) public {
        if (!rsidSettings[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }

        bool isRSIDOwner = msg.sender == users[rsid].addresses[0] || users[rsid].isDelegated[msg.sender];
        
        if (rsidSettings[rsid].delegateAddress != address(0)) {
            if (rsidSettings[rsid].delegateAddress != msg.sender) {
                revert E_ONLY_DELEGATE_CAN_REMOVE_OTHER_ADDRESSES();
            }
        } else {
            if (!isRSIDOwner) {
                revert E_ONLY_ASSOCIATED_OR_DELEGATE_CAN_REMOVE_OTHER_ADDRESSES();
            }
        }

        for (uint i = 0; i < users[rsid].addresses.length; i++) {
            if (users[rsid].addresses[i] == associatedAddress) {
                users[rsid].addresses[i] = users[rsid].addresses[users[rsid].addresses.length - 1];
                users[rsid].addresses.pop();
                break;
            }
        }

        for (uint i = 0; i < rsidOfAddress[associatedAddress].length; i++) {
            if (rsidOfAddress[associatedAddress][i] == rsid) {
                rsidOfAddress[associatedAddress][i] = rsidOfAddress[associatedAddress][rsidOfAddress[associatedAddress].length - 1];
                rsidOfAddress[associatedAddress].pop();
                break;
            }
        }

        users[rsid].isAssociated[associatedAddress] = false;

        emit AddressesUpdated(rsid, users[rsid].addresses);
    }

    function setRegistrationFee(uint256 newFee) public onlyOwner {
        registrationFee = newFee;

        emit RegistrationFeeChanged(newFee);
    }

    function setMaxRSIDsPerAddress(uint256 newMax) public onlyOwner {
        maxRSIDsPerAddress = newMax;

        emit MaxRSIDsPerAddressChanged(newMax);
    }
}
