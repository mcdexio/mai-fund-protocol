pragma solidity 0.5.15;

library LibList {

    struct AddressList {
        // max limit of address added to list
        uint256 limit;
        address[] addressList;
        mapping (address => bool) addresses;
    }

    /// @dev Initalize a list instance, set capability.
    /// @param list Storage of list
    /// @param limit Capability of the list.
    function initialize(AddressList storage list, uint256 limit) internal {
        require(limit > 0, "invalid limit");
        list.limit = limit;
    }

    /// @dev Get if an addresses is in list
    function has(AddressList storage list, address target) internal view returns (bool) {
        return list.addresses[target];
    }

    /// @dev Get if a list is full
    function isFull(AddressList storage list) internal view returns (bool) {
        return list.addressList.length == list.limit;
    }

    /// @dev Get all addresses in list
    function all(AddressList storage list) internal view returns (address[] memory) {
        return list.addressList;
    }

    /// @dev add Address into list
    /// @param list Storage of list
    /// @param target Address to add
    function add(AddressList storage list, address target) internal {
        require(!list.addresses[target], "duplicated");
        require(list.limit == 0 || list.addressList.length < list.limit, "full");

        list.addresses[target] = true;
        list.addressList.push(target);
    }

    /// @dev remove Address from list
    /// @param list Storage of list
    /// @param target Address to add
    function remove(AddressList storage list, address target) internal {
        require(list.addresses[target], "not exist");

        delete list.addresses[target];
        for (uint i = 0; i < list.addressList.length; i++){
            if(list.addressList[i] == target) {
                list.addressList[i] = list.addressList[list.addressList.length - 1];
                list.addressList.length -= 1;
                break;
            }
        }
    }
}