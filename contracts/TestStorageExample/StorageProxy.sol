pragma solidity ^0.5.0;
// Taken from: https://blog.openzeppelin.com/smart-contract-upgradeability-using-eternal-storage/

import "@openzeppelin/upgrades/contracts/upgradeability/UpgradeabilityProxy.sol";
import "./Storage.sol";


contract StorageProxy is UpgradeabilityProxy, Storage {}
