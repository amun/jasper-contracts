pragma solidity ^0.5.0;


interface InterfaceKYCVerifier {
    function isAddressWhitelisted(address) external view returns (bool);
}
