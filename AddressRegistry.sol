// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title Address Registry Contract
 * @dev This contract allows addresses to register and associate themselves with unique RSIDs. 
 * It also allows for the delegation of permissions and tagging of contracts for each RSID.
 */
contract AddressRegistry is Ownable {
    using ECDSA for bytes32;

    uint256 public registrationFee;
    uint256 public maxRSIDsPerAddress;
    uint256 public lastRSID;
    uint256 public maxContractsTagged;

    struct Alias {
        uint256 rsid;
        address[] addresses;
        address delegateAddress;
        mapping(address => bool) isAssociated;
        bool exists;
    }

    mapping(uint256 => Alias) private aliases;
    mapping(address => uint256[]) private rsidOfAddress;
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

    /**
    * @dev Allows any associated address (unless a delegate is set) or a delegate of an RSID 
    * to add contracts to the list of tagged contracts for an RSID.
    * The total number of tagged contracts after addition must not exceed the maximum limit.
    * @param rsid The RSID for which the contracts will be tagged.
    * @param contractAddresses The addresses of the contracts to be tagged.
    */
    function addTaggedContracts(uint256 rsid, address[] memory contractAddresses) public {
        if (!aliases[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        if (!aliases[rsid].isAssociated[msg.sender] && aliases[rsid].delegateAddress != msg.sender) {
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

    /**
    * @dev Allows any associated address (unless a delegate is set) or a delegate of an RSID
    * to remove a contract from the list of tagged contracts for an RSID.
    * @param rsid The RSID from which the contract will be untagged.
    * @param contractAddress The address of the contract to be untagged.
    */
    function removeTaggedContract(uint256 rsid, address contractAddress) public {
        if (!aliases[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        if (!aliases[rsid].isAssociated[msg.sender] && aliases[rsid].delegateAddress != msg.sender) {
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

    /**
     * @dev Returns the list of contracts tagged for a given RSID.
     * @param rsid The RSID for which to retrieve the list of tagged contracts.
     * @return The list of addresses of the tagged contracts.
     */
    function getTaggedContracts(uint256 rsid) public view returns (address[] memory) {
        if (!aliases[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        bytes32 key = keccak256(abi.encodePacked(rsid));
        return taggedContracts[key];
    }

    /**
     * @dev Allows the contract owner to set the maximum number of contracts that can be tagged for an RSID.
     * @param newMax The new maximum number of tagged contracts.
     */
    function setMaxContractsTagged(uint256 newMax) public onlyOwner {
        maxContractsTagged = newMax;
        emit MaxContractsTaggedChanged(newMax);
    }

    /**
     * @dev Generates a new RSID. This is a private function and can only be called within the contract.
     * @return The newly generated RSID.
     */
    function _generateRSID() internal returns (uint256) {
        lastRSID++;
        return lastRSID;
    }

    /**
     * @dev Allows an address to create a new RSID if they pay the registration fee and they have not exceeded the maximum number of RSIDs per address.
     * The address becomes associated with the new RSID.
     */
    function createRSID() public payable {
        if (msg.value < registrationFee) {
            emit Error("Insufficient registration fee");
            return;
        }
        if (rsidOfAddress[msg.sender].length >= maxRSIDsPerAddress) {
            revert ERSID_EXCEEDED_MAX_RSIDS();
        }

        uint256 rsid = _generateRSID();
        aliases[rsid].addresses.push(msg.sender);
        aliases[rsid].isAssociated[msg.sender] = true;
        rsidOfAddress[msg.sender].push(rsid);
        aliases[rsid].exists = true;

        emit RSIDCreated(rsid, msg.sender);
    }


    /**
     * @dev Returns the list of addresses associated with a given RSID.
     * @param rsid The RSID for which to retrieve the list of associated addresses.
     * @return The list of addresses associated with the RSID.
     */
    function getAddresses(uint256 rsid) public view returns (address[] memory) {
        if (!aliases[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        return aliases[rsid].addresses;
    }

    /**
     * @dev Returns whether an address is a delegate of a given RSID.
     * @param rsid The RSID to check for the delegation.
     * @param anyAddress The address to check for the delegation.
     * @return True if the address is a delegate of the RSID, false otherwise.
     */
    function isAddressDelegated(uint256 rsid, address anyAddress) public view returns (bool) {
        if (!aliases[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        return aliases[rsid].delegateAddress == anyAddress;
    }


    /**
     * @dev Returns the RSID associated with an address.
     * If the address is not associated with any RSID, it reverts.
     * @param anyAddress The address for which to retrieve the associated RSID.
     * @return The RSID associated with the address.
     */
    function getRSIDOfAddress(address anyAddress) public view returns (uint256) {
        uint256 rsidCount = rsidOfAddress[anyAddress].length;
        if (rsidCount == 0) {
            revert ERSID_NOT_FOUND();
        }
        return rsidOfAddress[anyAddress][0];
    }

    /**
     * @dev Returns the RSID at a particular index associated with an address.
     * If the index is out of range, it reverts.
     * @param anyAddress The address for which to retrieve the associated RSID.
     * @param index The index of the RSID to retrieve.
     * @return The RSID associated with the address at the given index.
     */
    function getRSIDOfAddress(address anyAddress, uint256 index) public view returns (uint256) {
        uint256 rsidCount = rsidOfAddress[anyAddress].length;
        if (index >= rsidCount) {
            revert EINDEX_OUT_OF_RANGE();
        }
        return rsidOfAddress[anyAddress][index];
    }

/**
 * @dev Allows an already associated address or a delegate (if one is set) of an RSID 
 * to add new addresses to the list of associated addresses for the RSID.
 * The total number of addresses associated with the RSID after addition must not exceed the maximum limit.
 * @param rsid The RSID for which the associated addresses will be updated.
 * @param newAddresses The new addresses to be associated with the RSID.
 */
function updateAddresses(uint256 rsid, address[] memory newAddresses) public {
        if (!aliases[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }

        if (!aliases[rsid].isAssociated[msg.sender] && aliases[rsid].delegateAddress != msg.sender) {
            revert ERSID_NOT_AUTHORIZED();
        }

        uint256 oldRSID = getRSIDOfAddress(msg.sender);
        if (oldRSID != 0 && oldRSID != rsid) {
            for (uint256 i = 0; i < aliases[oldRSID].addresses.length; i++) {
                if (aliases[oldRSID].addresses[i] == msg.sender) {
                    aliases[oldRSID].addresses[i] = aliases[oldRSID].addresses[aliases[oldRSID].addresses.length - 1];
                    aliases[oldRSID].addresses.pop();
                    break;
                }
            }
        }

        for (uint256 i = 0; i < newAddresses.length; i++) {
            if (rsidOfAddress[newAddresses[i]].length >= maxRSIDsPerAddress) {
                revert ERSID_EXCEEDED_MAX_RSIDS();
            }
            if (aliases[rsid].isAssociated[newAddresses[i]]) {
                revert ERSID_ALREADY_ASSOCIATED();
            }
            aliases[rsid].addresses.push(newAddresses[i]);
            aliases[rsid].isAssociated[newAddresses[i]] = true;
            rsidOfAddress[newAddresses[i]].push(rsid);
        }

        emit AddressesUpdated(rsid, newAddresses);
    }

    /**
     * @dev Allows an associated address of an RSID to delegate their permissions to another address.
     * The address must already be associated with the RSID, and the RSID cannot already have a delegate.
     * @param rsid The RSID for which the permissions will be delegated.
     * @param delegatedAddress The address to which the permissions will be delegated.
     */
    function addDelegatedAddress(uint256 rsid, address delegatedAddress) public {
        if (!aliases[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        if (aliases[rsid].delegateAddress != address(0)) {
            revert ERSID_DELEGATED_ADDRESS_ALREADY_EXISTS();
        }
        if (!aliases[rsid].isAssociated[delegatedAddress]) {
            revert ERSID_NOT_AUTHORIZED();
        }

        bool isAssociatedAddress = false;
        for (uint i = 0; i < aliases[rsid].addresses.length; i++) {
            if (aliases[rsid].addresses[i] == msg.sender) {
                isAssociatedAddress = true;
                break;
            }
        }

        if (!isAssociatedAddress) {
            revert E_ONLY_ASSOCIATED_CAN_DELEGATE();
        }

        aliases[rsid].delegateAddress = delegatedAddress;

        emit DelegatedAddressAdded(rsid, delegatedAddress);
    }


    /**
     * @dev Allows the delegate of an RSID to transfer their delegation to another address.
     * The sender must be the current delegate of the RSID.
     * @param rsid The RSID for which the delegation will be transferred.
     * @param newDelegatedAddress The address to which the delegation will be transferred.
     */
    function changeDelegatedAddress(uint256 rsid, address newDelegatedAddress) public {
        if (!aliases[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }

        if (aliases[rsid].delegateAddress != msg.sender) {
            revert E_ONLY_CURRENT_DELEGATE_CAN_CHANGE();
        }

        aliases[rsid].delegateAddress = newDelegatedAddress;

        emit DelegatedAddressAdded(rsid, newDelegatedAddress);
    }


    /**
     * @dev Allows an associated address of an RSID to remove the delegate of the RSID.
     * The sender must be an associated address of the RSID.
     * @param rsid The RSID for which the delegate will be removed.
     * @param delegatedAddress The address of the delegate to be removed.
     */
    function removeDelegatedAddress(uint256 rsid, address delegatedAddress) public {
        if (!aliases[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        if (aliases[rsid].delegateAddress != delegatedAddress) {
            revert ERSID_DELEGATED_ADDRESS_NOT_FOUND();
        }

        if (!aliases[rsid].isAssociated[msg.sender]) {
            revert E_ONLY_ASSOCIATED_CAN_REMOVE_DELEGATE();
        }
        
        aliases[rsid].delegateAddress = address(0);

        emit DelegatedAddressRemoved(rsid, delegatedAddress);
    }


    /**
     * @dev Allows an associated address of an RSID to remove itself from the list of associated addresses of the RSID.
     * The sender must be an associated address of the RSID.
     * @param rsid The RSID from which the sender will be removed.
     */
    function removeSelfFromRSID(uint256 rsid) public {
        if (!aliases[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }
        if (!aliases[rsid].isAssociated[msg.sender]) {
            revert ERSID_NOT_AUTHORIZED();
        }

        for (uint i = 0; i < aliases[rsid].addresses.length; i++) {
            if (aliases[rsid].addresses[i] == msg.sender) {
                aliases[rsid].addresses[i] = aliases[rsid].addresses[aliases[rsid].addresses.length - 1];
                aliases[rsid].addresses.pop();
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

        aliases[rsid].isAssociated[msg.sender] = false;
    }

    /**
    * @dev Allows an already associated address or a delegate (if one is set) of an RSID
    * to remove an address from the list of associated addresses of the RSID.
    * The address to be removed must already be associated with the RSID.
    * @param rsid The RSID from which the address will be removed.
    * @param associatedAddress The address to be removed.
    */
    function removeAssociatedAddressFromRSID(uint256 rsid, address associatedAddress) public {
        if (!aliases[rsid].exists) {
            revert ERSID_NOT_EXIST();
        }

        if (!aliases[rsid].isAssociated[associatedAddress]) {
            revert ERSID_NOT_AUTHORIZED();
        }

        bool isAssociatedAddress = msg.sender == aliases[rsid].addresses[0] || aliases[rsid].delegateAddress == msg.sender;
        
        if (aliases[rsid].delegateAddress != address(0)) {
            if (aliases[rsid].delegateAddress != msg.sender) {
                revert E_ONLY_DELEGATE_CAN_REMOVE_OTHER_ADDRESSES();
            }
        } else {
            if (!isAssociatedAddress) {
                revert E_ONLY_ASSOCIATED_OR_DELEGATE_CAN_REMOVE_OTHER_ADDRESSES();
            }
        }

        for (uint i = 0; i < aliases[rsid].addresses.length; i++) {
            if (aliases[rsid].addresses[i] == associatedAddress) {
                aliases[rsid].addresses[i] = aliases[rsid].addresses[aliases[rsid].addresses.length - 1];
                aliases[rsid].addresses.pop();
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

        aliases[rsid].isAssociated[associatedAddress] = false;

        emit AddressesUpdated(rsid, aliases[rsid].addresses);
    }

    /**
     * @dev Allows the contract owner to set the registration fee for creating a new RSID.
     * @param newFee The new registration fee.
     */
    function setRegistrationFee(uint256 newFee) public onlyOwner {
        registrationFee = newFee;

        emit RegistrationFeeChanged(newFee);
    }

    /**
     * @dev Allows the contract owner to set the maximum number of RSIDs that can be associated with an address.
     * @param newMax The new maximum number of RSIDs per address.
     */
    function setMaxRSIDsPerAddress(uint256 newMax) public onlyOwner {
        maxRSIDsPerAddress = newMax;

        emit MaxRSIDsPerAddressChanged(newMax);
    }
}