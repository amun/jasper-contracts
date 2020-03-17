pragma solidity ^0.5.0;

import '@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol';

contract Storage is Ownable {
  uint public instrumentCounter;
  mapping (string => uint) instruments;
  mapping (address => uint[]) public allowedInstruments;
  event AddInstrument(string addedInstrument);

  function getInstrumentIndex(string memory instrument) public view returns(uint) {
    return instruments[instrument];
  }

  function insertInstrument(string memory instrument) public onlyOwner {
    require(instruments[instrument] == 0, 'instrument already exists');
    instrumentCounter = instrumentCounter + 1;
    instruments[instrument] = instrumentCounter;
    emit AddInstrument(instrument);
  }

  function addAllowedInstruments(address user, string memory instrument) public  onlyOwner {
    require(instruments[instrument] != 0, 'instrument does not exist');
    allowedInstruments[user].push(instruments[instrument]);
  }

  function getUserAllowedInstruments(address user) public view returns(uint[] memory) {
    return allowedInstruments[user];
  }
}