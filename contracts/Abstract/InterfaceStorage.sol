pragma solidity ^0.5.0;

interface InterfaceStorage {
    function whitelistedAddresses(address) external view returns(bool);
}