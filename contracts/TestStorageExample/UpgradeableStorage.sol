pragma solidity ^0.5.0;
// Taken from: https://blog.openzeppelin.com/smart-contract-upgradeability-using-eternal-storage/

import '@openzeppelin/upgrades/contracts/upgradeability/InitializableUpgradeabilityProxy.sol';
import './Storage.sol';

contract UpgradeableStorage is InitializableUpgradeabilityProxy, Storage {}