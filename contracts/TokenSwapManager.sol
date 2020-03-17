pragma solidity ^0.5.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "solidity-util/lib/Strings.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "./CollateralPool.sol";
import "./KYCVerifier.sol";
import "./CompositionCalculator.sol";

import "./Abstract/InterfaceInverseToken.sol";
import "./PersistentStorage.sol";
import "./utils/Math.sol";


contract TokenSwapManager is Initializable {
  using Strings for string;
  using SafeMath for uint256;

  address public bridge;
  address public stablecoin;
  address public inverseToken;

  KYCVerifier public kycVerifier;
  CollateralPool public collateralPool;
  PersistentStorage public persistentStorage;
  CompositionCalculator public compositionCalculator;

  event SuccessfulOrder(
    string orderType,
    address whitelistedAddress,
    uint256 tokensGiven,
    uint256 tokensRecieved
  );

  event RebalanceEvent(
    uint256 price,
    uint256 cashPositionPerToken,
    uint256 balancePerToken,
    uint256 lendingFee
  );

  function initialize(
      address _bridge,
      address _stablecoin,
      address _inverseToken,
      address _persistentStorage,
      address _kycVerifier,
      address _collateralPool,
      address _compositionCalculator
  ) public initializer {
      bridge = _bridge;
      stablecoin = _stablecoin;
      inverseToken = _inverseToken;

      persistentStorage = PersistentStorage(_persistentStorage);
      kycVerifier = KYCVerifier(_kycVerifier);
      collateralPool = CollateralPool(_collateralPool);
      compositionCalculator = CompositionCalculator(_compositionCalculator);
  }


  //////////////// Create + Redeem Order Request ////////////////
  //////////////// Create: Recieve Inverse Token   ////////////////
  //////////////// Redeem: Recieve Stable Coin ////////////////


  function createOrder(
    string memory result,
    string memory message,
    uint256 tokensGiven,
    uint256 tokensRecieved,
    uint256 avgBlendedFee,
    address whitelistedAddress
  )
    public
    returns (bool success)
  {

    // Require is Whitelisted
    require(kycVerifier.isAddressWhitelisted(whitelistedAddress), 'only whitelisted address may place orders');


    // Return Funds if Bridge Pass an Error
    if (result.compareTo("ERROR")) {
      transferTokenFromPool(stablecoin, whitelistedAddress, tokensGiven);
      return false;
    }

    // TODO: Check Data with Composition Calculator

    // Save Order to Storage and Lock Funds for 1 Hour
    persistentStorage.setOrderByUser(whitelistedAddress, "CREATE", tokensGiven, tokensRecieved, avgBlendedFee, 100000000);
    persistentStorage.setOrder("CREATE", tokensGiven, tokensRecieved, avgBlendedFee, 100000000);
    persistentStorage.setLockedOrderForUser(whitelistedAddress, tokensRecieved, block.timestamp);

    // Write Successful Order to Log
    writeOrderResponse("CREATE", whitelistedAddress, tokensGiven, tokensRecieved);

    // Mint Tokens to Address
    InterfaceInverseToken token = InterfaceInverseToken(inverseToken);
    token.mintTokens(whitelistedAddress, tokensRecieved);


    return true;

  }

  function redeemOrder(
    string memory result,
    string memory message,
    uint256 tokensGiven,
    uint256 tokensRecieved,
    uint256 avgBlendedFee,
    address whitelistedAddress
  )
    public
    returns (bool success)
  {
    // Require Unlocked and Whitelisted
    uint256 lockedAmount = getLockedAmount(whitelistedAddress);
    require(lockedAmount == 0 || tokensGiven < lockedAmount, 'cannot redeem locked tokens');
    require(kycVerifier.isAddressWhitelisted(whitelistedAddress), 'only whitelisted address may place orders');


    // Return Funds if Bridge Pass an Error
    if (result.compareTo("ERROR")) {
      transferTokenFromPool(inverseToken ,whitelistedAddress, tokensGiven);
      return false;
    }

    // TODO: Check Data with Composition Calculator

    // Save To Storage
    persistentStorage.setOrderByUser(whitelistedAddress,"REDEEM", tokensGiven, tokensRecieved, avgBlendedFee, 100000000);
    persistentStorage.setOrder("REDEEM", tokensGiven, tokensRecieved, avgBlendedFee, 100000000);

    // Write Successful Order Log
    writeOrderResponse("REDEEM", whitelistedAddress, tokensGiven, tokensRecieved);

    // Burn Tokens to Address
    InterfaceInverseToken token = InterfaceInverseToken(inverseToken);
    token.burnTokens(address(collateralPool), tokensGiven);


    return true;

  }

  function writeOrderResponse(
    string memory orderType,
    address whiteListedAddress,
    uint256 tokensGiven,
    uint256 tokensRecieved
  )
    internal
  {
    require (tokensGiven > 0 && tokensRecieved > 0, 'amount must be greater than 0');
    require (orderType.compareTo('CREATE') || orderType.compareTo('REDEEM'), 'must be create or redeem');
    require (whiteListedAddress != address(0), 'address cannot be 0');

    emit SuccessfulOrder(orderType, whiteListedAddress, tokensGiven, tokensRecieved);
  }

  function getLockedAmount(address recieverAddress)
    public
    view
    returns (uint256 lockedAmount)
  {
    uint256 count = persistentStorage.getLockedOrdersArraySize(recieverAddress);
    for (uint256 index = count; index > 0; index--) {
      uint256 timestamp;
      uint256 amountOfTokens;

      (amountOfTokens, timestamp) = persistentStorage.getLockedOrderForUser(recieverAddress, index-1);
      if (block.timestamp.sub(timestamp) > 3600) break;
      lockedAmount = lockedAmount.add(amountOfTokens);
    }

    return lockedAmount;
  }



    ////////////////    Daily Rebalance     ////////////////
    //////////////// Threshold Rebalance    ////////////////

    function _dailyRebalance(
        uint256 _price,
        uint256 _lendingFeeCalc,
        uint256 _lendingFeeToSet,
        uint256 _endCashPosition,
        uint256 _endBalance,
        uint256 _totalTokenSupply
    ) internal {

        // Rebalance Inputs : Trade Execution Price + Updated Loan Positions (repaid and outstanding)
        // Rebalance Outputs : Collateral Pool Adjustment + Updated PCF (calculated through CompositionCalculator.sol)
        // Collater Pool Adjustment Handled Through Helper Functions Below
        uint256 endBalance;
        uint256 endCashPosition;
        (, endBalance, endCashPosition, , , ) = compositionCalculator
            .calculateDailyPCF(_price, _lendingFeeCalc);
        uint256 totalTokenSupply = InterfaceInverseToken(inverseToken)
            .totalSupply();

        require(
            totalTokenSupply != 0,
            "The total token supply should not be zero."
        );
        require(
            totalTokenSupply == _totalTokenSupply,
            "The total token supply should match."
        );
        require(
            endCashPosition == _endCashPosition,
            "The cash positions should match."
        );
        require(endBalance == _endBalance, "The balance should match.");

        uint256 cashPositionPerToken = DSMath.wdiv(
            endCashPosition,
            totalTokenSupply
        );
        uint256 balancePerToken = DSMath.wdiv(endBalance, totalTokenSupply);
        persistentStorage.setAccounting(
            _price,
            cashPositionPerToken,
            balancePerToken,
            _lendingFeeToSet
        );
        emit RebalanceEvent(
            _price,
            cashPositionPerToken,
            balancePerToken,
            _lendingFeeToSet
        );
    }
    /**
    * @dev Sets the accounting of today for the curent price
    * @param _price The momentary price of the crypto
    * @param _lendingFee The blended lending fee of the balance
    * @param _endCashPosition The total cashpostion on the product
    * @param _endBalance The total dept on the product
    * @param _totalTokenSupply The token supply with witch expected
    */
    function dailyRebalance(
        uint256 _price,
        uint256 _lendingFee,
        uint256 _endCashPosition,
        uint256 _endBalance,
        uint256 _totalTokenSupply
    ) public {
        // Rebalance Inputs : Trade Execution Price + Updated Loan Positions (repaid and outstanding)
        // Rebalance Outputs : Collateral Pool Adjustment + Updated PCF (calculated through CompositionCalculator.sol)
        // Collater Pool Adjustment Handled Through Helper Functions Below
        _dailyRebalance(
            _price,
            _lendingFee,
            _lendingFee,
            _endCashPosition,
            _endBalance,
            _totalTokenSupply
        );
    }

    /**
    * @dev Sets the accounting of today for the curent price
    * @param _price The momentary price of the crypto
    * @param _lendingFee The blended lending fee of the balance
    * @param _endCashPosition The total cashpostion on the product
    * @param _endBalance The total dept on the product
    * @param _totalTokenSupply The token supply with witch expected
    */
    function thresholdRebalance(
        uint256 _price,
        uint256 _lendingFee,
        uint256 _endCashPosition,
        uint256 _endBalance,
        uint256 _totalTokenSupply
    ) public {
        // First Sanity Check Threshold Crossing
        // Rebalance Inputs : Trade Execution Price + Updated Loan Positions (repaid and outstanding)
        // Rebalance Outputs : Collateral Pool Adjustment + Updated PCF (calculated through CompositionCalculator.sol)
        // Collater Pool Adjustment Handled Through Helper Functions Below
        _dailyRebalance(
            _price,
            0,
            _lendingFee,
            _endCashPosition,
            _endBalance,
            _totalTokenSupply
        );
    }

  //////////////// Transfer Stablecoin Out of Pool   ////////////////
  //////////////// Transfer Stablecoin In of Pool    ////////////////
  //////////////// Transfer InverseToken Out of Pool ////////////////
  //////////////// Transfer InverseToken In of Pool  ////////////////

  function transferTokenToPool(address tokenContract, address whiteListedAddress, uint256 orderAmount)
    internal
    returns (bool)
  {
    // Check orderAmount <= availableAmount
    // Transfer USDC to Stablecoin Collateral Pool
    return collateralPool.moveTokenToPool(tokenContract, whiteListedAddress, orderAmount);
  }

  function transferTokenFromPool(address tokenContract, address destinationAddress, uint256 orderAmount)
    internal
    returns (bool)
  {
    // Check orderAmount <= availableAmount
    // Transfer USDC to Destination Address
    return collateralPool.moveTokenfromPool(tokenContract, destinationAddress, orderAmount);
  }

}
