pragma solidity ^0.5.0;

import '@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol';
import './Token/InverseToken.sol';
import './KYCVerifier.sol';

contract CollateralPool is Ownable {
  KYCVerifier public kycVerifier;

  function initialize(address ownerAddress, address _kycVerifier) public initializer {
    initialize(ownerAddress);
    kycVerifier = KYCVerifier(_kycVerifier);
  }

  function moveTokenToPool(address _token, address whiteListedAddress, uint orderAmount)
    public
    onlyOwner
    returns (bool)
  {
    InverseToken token_ = InverseToken(_token);
    require(kycVerifier.isAddressWhitelisted(whiteListedAddress), 'only whitelisted address are allowed to move tokens to pool');
    require(orderAmount <= token_.allowance(whiteListedAddress, address(this)), 'cannot move more funds than allowed');

    token_.transferFrom(whiteListedAddress, address(this), orderAmount);
    return true;
  }

  function moveTokenfromPool(address _token, address destinationAddress, uint orderAmount)
    public
    onlyOwner
    returns (bool)
  {
    InverseToken token_ = InverseToken(_token);
    require(orderAmount <= token_.balanceOf(address(this)), 'cannot move more funds than owned');

    token_.transfer(destinationAddress, orderAmount);
    return true;
  }
}