pragma solidity ^0.5.0;

import './ERC20.sol';

contract InverseToken is ERC20 {
  function mintTokens(address destinationAddress, uint amountToMint)
    public
    onlyOwnerOrTokenSwap()
    returns (bool)
  {
    // Mint Tokens on Successful Creation order
    _mint(destinationAddress, amountToMint);
    return true;

  }

  function burnTokens(address fromAddress, uint amountToBurn)
    public
    onlyOwnerOrTokenSwap()
    returns (bool)
  {
    // Burn Tokens on Successful Redemption Order
    _burn(fromAddress, amountToBurn);
    return true;
  }

  modifier onlyOwnerOrTokenSwap() {
      require(isOwner() || _msgSender() == _persistenStorage.tokenSwapManager(), "caller is not the owner or token swap manager");
      _;
  }

  uint256[50] private ______gap;
}