pragma solidity ^0.5.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "./Abstract/InterfaceStorage.sol";

contract KYCVerifier is Initializable {
  InterfaceStorage public persistentStorage;

  function initialize(address _persistentStorage) public initializer {
    persistentStorage = InterfaceStorage(_persistentStorage);
  }

  function isAddressWhitelisted(address userAddress) public view returns(bool) {
    return persistentStorage.whitelistedAddresses(userAddress);
  }
}