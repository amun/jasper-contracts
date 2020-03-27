pragma solidity ^0.5.0;

import '@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';
import "./Abstract/InterfaceInverseToken.sol";
import "./PersistentStorage.sol";
import './KYCVerifier.sol';

contract CollateralPool is Ownable {
  using SafeMath for uint256;
  KYCVerifier public kycVerifier;
  PersistentStorage public persistentStorage;

  uint256[2] public percentageOfFundsForColdStorage;
  address public coldStorage;

  event SetPercentageOfFundsForColdStorageEvent(uint256[2] newPercentageOfFundsForColdStorage);

  function initialize(
    address ownerAddress,
    address _kycVerifier,
    address _persistentStorage,
    address _coldStorage,
    uint256[2] memory _percentageOfFundsForColdStorage
  )
    public
    initializer
  {
    require(
      ownerAddress != address(0) &&
      _kycVerifier != address(0) &&
      _coldStorage != address(0) &&
      _percentageOfFundsForColdStorage[0] != 0 &&
      _percentageOfFundsForColdStorage[1] != 0,
      "params variables cannot be empty"
    );
    initialize(ownerAddress);
    kycVerifier = KYCVerifier(_kycVerifier);
    persistentStorage = PersistentStorage(_persistentStorage);
    coldStorage = _coldStorage;
    percentageOfFundsForColdStorage = _percentageOfFundsForColdStorage;
  }

  // @dev Move tokens to collateral pool
  // @param _token ERC20 address
  // @param whiteListedAddress address allowed to transfer to pool
  // @param orderAmount amount to transfer to collateral pool
  function moveTokenToPool(address _token, address whiteListedAddress, uint256 orderAmount)
    public
    onlyOwnerOrTokenSwap
    returns (bool)
  {
    InterfaceInverseToken token_ = InterfaceInverseToken(_token);
    require(kycVerifier.isAddressWhitelisted(whiteListedAddress), 'only whitelisted address are allowed to move tokens to pool');
    require(orderAmount <= token_.allowance(whiteListedAddress, address(this)), 'cannot move more funds than allowed');

    uint256 percentageNumerator = percentageOfFundsForColdStorage[0];
    uint256 percentageDenominator = percentageOfFundsForColdStorage[1];
    uint256 amountForColdStorage = orderAmount.mul(percentageNumerator).div(percentageDenominator);

    token_.transferFrom(whiteListedAddress, address(this), orderAmount);
    token_.transfer(coldStorage, amountForColdStorage);

    return true;
  }

  // @dev Move tokens out of collateral pool
  // @param _token ERC20 address
  // @param destinationAddress address to send to
  // @param orderAmount amount to transfer from collateral pool
  function moveTokenfromPool(address _token, address destinationAddress, uint256 orderAmount)
    public
    onlyOwnerOrTokenSwap()
    returns (bool)
  {
    InterfaceInverseToken token_ = InterfaceInverseToken(_token);
    require(orderAmount <= token_.balanceOf(address(this)), 'cannot move more funds than owned');

    token_.transfer(destinationAddress, orderAmount);
    return true;
  }

  modifier onlyOwnerOrTokenSwap() {
      require(isOwner() || _msgSender() == persistentStorage.tokenSwapManager(), "caller is not the owner or token swap manager");
      _;
  }
  
  // @dev Sets new coldStorage
  // @param _newColdStorage Address for new cold storage wallet
  function setColdStorage(address _newColdStorage) public onlyOwner {
    require(_newColdStorage != address(0), 'address cannot be empty');
    coldStorage = _newColdStorage;
  }

  // @dev Sets percentage of funds to stay in contract. Owner only
  // @param _newPercentageOfFundsForColdStorage List with two elements referencing percentage of funds for cold storage as a fraction
  // e.g. 1/2 is [1,2]
  function setPercentageOfFundsForColdStorage(uint256[2] memory _newPercentageOfFundsForColdStorage)
    public
    onlyOwner
  {
      require(_newPercentageOfFundsForColdStorage[0] != 0 && _newPercentageOfFundsForColdStorage[1] != 0, 'none of the values can be zero');
      percentageOfFundsForColdStorage[0] = _newPercentageOfFundsForColdStorage[0];
      percentageOfFundsForColdStorage[1] = _newPercentageOfFundsForColdStorage[1];

      emit SetPercentageOfFundsForColdStorageEvent(_newPercentageOfFundsForColdStorage);
  }
}