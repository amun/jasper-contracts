pragma solidity ^0.5.0;

import "./UpgradeableStorage.sol";


contract Storage_V0 is UpgradeableStorage {
    function test_storage_v0() public view returns (uint256) {
        return instrumentCounter;
    }
}


contract Storage_V1 is UpgradeableStorage {
    function test_storage_v1() public view returns (uint256) {
        return instrumentCounter + 1;
    }
}
