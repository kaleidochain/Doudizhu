pragma solidity >=0.4.21 <0.6.0;

library NotaryMaps {
    struct NotaryInfo {
        address addr;           // notary链上的地址
        string  nodeid;         // notary的node id
        uint    pawnAmount;     // 抵押金额
        uint    locktime;       // 账户锁定时间
    }

    /* mapAddressNotaryInfo mapping
        KeyIndex address => Value NotaryInfo
    */
    struct entryAddrNotaryInfo {
        // Equal to the index of the key of this item in keys, plus 1.
        uint keyIndex;
        NotaryInfo value;
    }

    struct MapAddr2Notary {
        mapping(address => entryAddrNotaryInfo) data;
        address[] keys;
    }

    function insert(MapAddr2Notary storage self, address key, NotaryInfo memory value) internal returns (bool replaced) {
        entryAddrNotaryInfo storage e = self.data[key];
        e.value = value;
        if (e.keyIndex > 0) {
            return true;
        } else {
            e.keyIndex = ++self.keys.length;
            self.keys[e.keyIndex - 1] = key;
            return false;
        }
    }

    function remove(MapAddr2Notary storage self, address key) internal returns (bool success) {
        entryAddrNotaryInfo storage e = self.data[key];
        if (e.keyIndex == 0)
            return false;

        if (e.keyIndex <= self.keys.length) {
            // Move an existing element into the vacated key slot.
            self.data[self.keys[self.keys.length - 1]].keyIndex = e.keyIndex;
            self.keys[e.keyIndex - 1] = self.keys[self.keys.length - 1];
            self.keys.length -= 1;
            delete self.data[key];
            return true;
        }
    }

    function destroy(MapAddr2Notary storage self) internal {
        for (uint i = 0; i < self.keys.length; i++) {
            delete self.data[self.keys[i]];
        }
        delete self.keys;
        return;
    }

    function contains(MapAddr2Notary storage self, address key) internal view returns (bool exists) {
        return self.data[key].keyIndex > 0;
    }

    function size(MapAddr2Notary storage self) internal view returns (uint) {
        return self.keys.length;
    }

    function getValueByKey(MapAddr2Notary storage self, address key) internal view returns (NotaryInfo memory) {
        return self.data[key].value;
    }

    function getKeyByIndex(MapAddr2Notary storage self, uint idx) internal view returns (address) {
        return self.keys[idx];
    }

    function getIndexByKey(MapAddr2Notary storage self, address key) internal view returns (uint) {
        return self.data[key].keyIndex - 1;
    }

    function getValueByIndex(MapAddr2Notary storage self, uint idx) internal view returns (NotaryInfo memory) {
        return self.data[self.keys[idx]].value;
    }
}