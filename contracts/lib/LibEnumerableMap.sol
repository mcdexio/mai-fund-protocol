// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/utils/EnumerableMap.sol";

library LibEnumerableMap {

    struct MapEntry {
        uint256 _key;
        uint256 _value;
    }

    struct AppendOnlyUintToUintMap {
        // Storage of map keys and values
        MapEntry[] _entries;
        // Position of the entry defined by a key in the `entries` array, plus 1
        // because index 0 means a key is not in the map.
        mapping (uint256 => uint256) _indexes;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(AppendOnlyUintToUintMap storage map, uint256 key, uint256 value) internal returns (bool) {
        // We read and store the key's index to prevent multiple reads from the same storage slot
        uint256 keyIndex = map._indexes[key];

        if (keyIndex == 0) { // Equivalent to !contains(map, key)
            map._entries.push(MapEntry({ _key: key, _value: value }));
            // The entry is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            map._indexes[key] = map._entries.length;
            return true;
        } else {
            map._entries[keyIndex - 1]._value = value;
            return false;
        }
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(AppendOnlyUintToUintMap storage map, uint256 key) internal view returns (bool) {
        return map._indexes[key] != 0;
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(AppendOnlyUintToUintMap storage map) internal view returns (uint256) {
        return map._entries.length;
    }

   /**
    * @dev Returns the element stored at position `index` in the set. O(1).
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(AppendOnlyUintToUintMap storage map, uint256 index) internal view returns (uint256) {
        require(map._entries.length > index, "index out of bounds");
        return map._entries[index]._value;
    }

    function index(AppendOnlyUintToUintMap storage map, uint256 key) internal view returns (uint256) {
        return map._indexes[key];
    }

    /**
     * @dev Returns the value associated with `key`.  O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(AppendOnlyUintToUintMap storage map, uint256 key) internal view returns (uint256) {
        uint256 keyIndex = map._indexes[key];
        require(keyIndex != 0, "key not exist"); // Equivalent to contains(map, key)
        return map._entries[keyIndex - 1]._value; // All indexes are 1-based
    }
}