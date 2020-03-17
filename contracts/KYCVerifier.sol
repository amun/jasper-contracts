pragma solidity ^0.5.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "./Abstract/Storage.sol";

contract KYCVerifier is Initializable {
  Storage public persistentStorage;

  function initialize(address _persistentStorage) public initializer {
    persistentStorage = Storage(_persistentStorage);
  }

  function isAddressWhitelisted(address userAddress) public view returns(bool) {
    return persistentStorage.whitelistedAddresses(userAddress);
  }
}