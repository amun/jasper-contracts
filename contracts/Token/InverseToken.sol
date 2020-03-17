pragma solidity ^0.5.0;

import './Token/ERC20.sol';

contract InverseToken is ERC20 {
  function mintTokens(address destinationAddress, uint amountToMint)
    public
    // Add Modifier To Limit Minting to Inverse Providers
    returns (bool)
  {
    // Mint Tokens on Successful Creation order
    _mint(destinationAddress, amountToMint);
    return true;

  }

  function burnTokens(address fromAddress, uint amountToBurn)
    public
    // Add Modifier to Limit Burning to Inverse Providers
    returns (bool)
  {
    // Burn Tokens on Successful Redemption Order
    _burn(fromAddress, amountToBurn);
    return true;
  }

  uint256[50] private ______gap;
}