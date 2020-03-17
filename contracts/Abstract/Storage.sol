pragma solidity ^0.5.0;

interface Storage {
    function whitelistedAddresses(address) external view returns(bool);
}