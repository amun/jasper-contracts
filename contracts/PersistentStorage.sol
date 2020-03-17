pragma solidity ^0.5.0;

import '@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol';
import './utils/DateTimeLibrary.sol';

contract PersistentStorage is Ownable {

  address public tokenSwapManager;

  function setTokenSwapManager(address _tokenSwapManager) public onlyOwner {
    tokenSwapManager = _tokenSwapManager;
  }

  struct Accounting {
    uint256 price;
    uint256 cashPositionPerToken;
    uint256 balancePerToken;
    uint256 lendingFee;
  }

  struct CreateOrderTimestamp {
    uint256 numOfTokens;
    uint256 timestamp;
  }

  struct Order {
    string orderType;
    uint256 tokensGiven;
    uint256 tokensRecieved;
    uint256 avgBlendedFee;
  }

  uint256 public lastActivityDay;
  uint256 public minRebalanceAmount;

  mapping (uint256 => Accounting) private accounting;
  mapping (address => bool) public whitelistedAddresses;

  Order[] public allOrders;
  mapping (address => Order[]) public orderByUser;
  mapping (address => CreateOrderTimestamp[]) public lockedOrders;


  event AccountingValuesSet(uint256 today);
  event RebalanceValuesSet(uint256 newMinRebalanceAmount);

  /**
  * @dev Throws if called by any account other than the owner.
  */
  modifier onlyOwnerOrTokenSwap() {
      require(isOwner() || _msgSender() == tokenSwapManager, "caller is not the owner or token swap manager");
      _;
  }

  /*
  * Saves order in mapping (address => Order[]) orderByUser
  * orderIndex == 100000000, append to Order[]
  * orderIndex != 100000000, overwrite element at orderIndex
  */

  function setOrderByUser(
    address whitelistedAddress,
    string memory orderType,
    uint256 tokensGiven,
    uint256 tokensRecieved,
    uint256 avgBlendedFee,
    uint256 orderIndex
  )
    public
  {
    Order memory newOrder = Order(
      orderType,
      tokensGiven,
      tokensRecieved,
      avgBlendedFee
    );

    if (orderIndex == 100000000) {
      orderByUser[whitelistedAddress].push(newOrder);
    } else {
      orderByUser[whitelistedAddress][orderIndex] = newOrder;
    }
  }

  /*
  * Gets Order[] For User Address
  * Return order at Index in Order[]
  */

  function getOrderByUser(
    address whitelistedAddress,
    uint256 orderIndex
  )
    public
    returns (string memory orderType, uint256 tokensGiven, uint256 tokensRecieved, uint256 avgBlendedFee)
  {
    Order storage orderAtIndex = orderByUser[whitelistedAddress][orderIndex];
    return (
      orderAtIndex.orderType,
      orderAtIndex.tokensGiven,
      orderAtIndex.tokensRecieved,
      orderAtIndex.avgBlendedFee

    );

  }

  /*
  * Save order to allOrders array
  * orderIndex == 100000000, append to allOrders array
  * orderIndex != 100000000, overwrite element at orderIndex
  */

  function setOrder(
    string memory orderType,
    uint256 tokensGiven,
    uint256 tokensRecieved,
    uint256 avgBlendedFee,
    uint256 orderIndex
  )
    public
  {
    Order memory newOrder = Order(
      orderType,
      tokensGiven,
      tokensRecieved,
      avgBlendedFee
    );

    if (orderIndex == 100000000) {
      allOrders.push(newOrder);
    } else {
      allOrders[orderIndex] = newOrder;
    }

  }

  /*
  * Saves order to allOrders array
  * orderIndex == 100000000, append to allOrders array
  * orderIndex != 100000000, overwrite element at orderIndex
  */

  function getOrder(uint256 index)
    public
    returns (string memory orderType, uint256 tokensGiven, uint256 tokensRecieved, uint256 avgBlendedFee)
  {
    Order storage orderAtIndex = allOrders[index];
    return (
      orderAtIndex.orderType,
      orderAtIndex.tokensGiven,
      orderAtIndex.tokensRecieved,
      orderAtIndex.avgBlendedFee
    );
  }

  /*
  * Saves order to mapping (address => CreateOrderTimestamp[]) lockedOrders
  * Appends order to CreateOrderTimestamp[]
  */

  function setLockedOrderForUser(
    address authorizedUser,
    uint256 lockedAmount,
    uint256 blockTimestamp
  )
    public
  {
    require(authorizedUser != address(0), 'adddress must not be empty');
    require(lockedAmount != 0, 'creation order must be greater than 0');

    CreateOrderTimestamp memory newCreateOrder = CreateOrderTimestamp(lockedAmount, blockTimestamp);
    CreateOrderTimestamp[] storage allCreateOrders = lockedOrders[authorizedUser];
    allCreateOrders.push(newCreateOrder);

  }

  /*
  * Get order from mapping (address => CreateOrderTimestamp[]) lockedOrders
  * Returns element at index in CreateOrderTimestamp[]
  */

  function getLockedOrderForUser(
    address authorizedUser,
    uint256 index
  )
    public
    view
    returns (uint256 timelockedAmount, uint256 blockTimestamp)
  {
    require(authorizedUser != address(0), 'adddress must not be empty');
    CreateOrderTimestamp[] memory allCreateOrders = lockedOrders[authorizedUser];

    return (
      allCreateOrders[index].numOfTokens,
      allCreateOrders[index].timestamp
    );
  }


  /*
  * Get CreateOrderTimestamp[] array size
  */
  function getLockedOrdersArraySize(address authorizedUser)
    public
    view
    returns (uint256 count)
  {
    require(authorizedUser != address(0), 'adddress must not be empty');
    CreateOrderTimestamp[] memory allCreateOrders = lockedOrders[authorizedUser];
    return allCreateOrders.length;
  }


  // @dev Set whitelisted addresses
  function setWhitelistedAddress(address adddressToAdd) public onlyOwner {
    require(adddressToAdd != address(0), 'adddress must not be empty');

    whitelistedAddresses[adddressToAdd] = true;
  }

  // @dev Remove whitelisted addresses
  function removeWhitelistedAddress(address addressToRemove) public onlyOwner {
    require(whitelistedAddresses[addressToRemove], 'address must be added to be removed allowed');

    delete whitelistedAddresses[addressToRemove];
  }

  // @dev Updates whitelisted addresses
  function updateWhitelistedAddress(address oldAddress, address newAddress) public {
    removeWhitelistedAddress(oldAddress);
    setWhitelistedAddress(newAddress);
  }

  // @dev Get accounting values for a specific day
  // @param date format as 20200123 for 23th of January 2020
  function getAccounting(uint256 date) public view returns (uint256, uint256, uint256, uint256) {
      return(
        accounting[date].price,
        accounting[date].cashPositionPerToken,
        accounting[date].balancePerToken,
        accounting[date].lendingFee
      );
  }

  // @dev Set accounting values for the day
  function setAccounting
    (
      uint256 _price,
      uint256 _cashPositionPerToken,
      uint256 _balancePerToken,
      uint256 _lendingFee
    )
      external
      onlyOwnerOrTokenSwap
  {
    (uint256 year, uint256 month, uint256 day) = DateTimeLibrary.timestampToDate(now);
    uint256 today = year * 10000 + month * 100 + day;
    
      accounting[today].price = _price;
      accounting[today].cashPositionPerToken = _cashPositionPerToken;
      accounting[today].balancePerToken = _balancePerToken;
      accounting[today].lendingFee = _lendingFee;

      lastActivityDay = today;
      emit AccountingValuesSet(today);
  }

  // @dev Set last rebalance information
  function setMinRebalanceAmount(uint256 _minRebalanceAmount) external onlyOwner {
    minRebalanceAmount = _minRebalanceAmount;

    emit RebalanceValuesSet(minRebalanceAmount);
  }

  // @dev Returns price
  function getPrice() public view returns (uint256 price) {
    return accounting[lastActivityDay].price;
  }

  // @dev Returns cash position amount
  function getCashPositionPerToken() public view returns (uint256 amount) {
      return accounting[lastActivityDay].cashPositionPerToken;
  }

  // @dev Returns borrowed crypto amount
  function getBalancePerToken() public view returns (uint256 amount) {
    return accounting[lastActivityDay].balancePerToken;
  }

  // @dev Returns lending fee
  function getLendingFee() public view returns (uint256 lendingRate) {
    return accounting[lastActivityDay].lendingFee;
  }
}