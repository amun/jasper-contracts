pragma solidity ^0.5.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "solidity-util/lib/Strings.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";

import "./CashPool.sol";
import "./KYCVerifier.sol";
import "./CompositionCalculator.sol";

import "./Abstract/InterfaceInverseToken.sol";
import "./PersistentStorage.sol";
import "./utils/Math.sol";


contract TokenSwapManager is Initializable, Ownable {
    using Strings for string;
    using SafeMath for uint256;

    address public stablecoin;
    address public inverseToken;

    KYCVerifier public kycVerifier;
    CashPool public cashPool;
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
        uint256 cashPositionPerTokenUnit,
        uint256 balancePerTokenUnit,
        uint256 lendingFee
    );

    function initialize(
        address _owner,
        address _stablecoin,
        address _inverseToken,
        address _cashPool,
        address _compositionCalculator
    ) public initializer {
        initialize(_owner);

        require(
            _owner != address(0) &&
                _stablecoin != address(0) &&
                _inverseToken != address(0) &&
                _cashPool != address(0) &&
                _compositionCalculator != address(0),
            "addresses cannot be zero"
        );

        stablecoin = _stablecoin;
        inverseToken = _inverseToken;

        cashPool = CashPool(_cashPool);
        persistentStorage = PersistentStorage(
            address(cashPool.persistentStorage())
        );
        kycVerifier = KYCVerifier(address(cashPool.kycVerifier()));
        compositionCalculator = CompositionCalculator(_compositionCalculator);
    }

    //////////////// Create + Redeem Order Request ////////////////
    //////////////// Create: Recieve Inverse Token   ////////////////
    //////////////// Redeem: Recieve Stable Coin ////////////////

    function createOrder(
        bool success,
        uint256 tokensGiven,
        uint256 tokensRecieved,
        uint256 avgBlendedFee,
        uint256 executionPrice,
        address whitelistedAddress
    ) public onlyOwnerOrBridge() notPausedOrShutdown() returns (bool retVal) {
        // Require is Whitelisted
        require(
            kycVerifier.isAddressWhitelisted(whitelistedAddress),
            "only whitelisted address may place orders"
        );

        // Return Funds if Bridge Pass an Error
        if (!success) {
            transferTokenFromPool(
                stablecoin,
                whitelistedAddress,
                normalizeUSDC(tokensGiven)
            );
            return false;
        }

        // Check Tokens Recieved with Composition Calculator
        uint256 _tokensRecieved = compositionCalculator
            .getCurrentTokenAmountCreatedByCash(tokensGiven, executionPrice);
        require(
            _tokensRecieved == tokensRecieved,
            "tokens created must equal tokens recieved"
        );

        // Save Order to Storage and Lock Funds for 1 Hour
        persistentStorage.setOrderByUser(
            whitelistedAddress,
            "CREATE",
            tokensGiven,
            tokensRecieved,
            avgBlendedFee,
            0,
            false
        );

        // Write Successful Order to Log
        writeOrderResponse(
            "CREATE",
            whitelistedAddress,
            tokensGiven,
            tokensRecieved
        );

        // Mint Tokens to Address
        InterfaceInverseToken token = InterfaceInverseToken(inverseToken);
        token.mintTokens(whitelistedAddress, tokensRecieved);

        return true;
    }

    function redeemOrder(
        bool success,
        uint256 tokensGiven,
        uint256 tokensRecieved,
        uint256 avgBlendedFee,
        uint256 executionPrice,
        address whitelistedAddress
    ) public onlyOwnerOrBridge() notPausedOrShutdown() returns (bool retVal) {
        // Require Whitelisted
        require(
            kycVerifier.isAddressWhitelisted(whitelistedAddress),
            "only whitelisted address may place orders"
        );

        // Return Funds if Bridge Pass an Error
        if (!success) {
            transferTokenFromPool(
                inverseToken,
                whitelistedAddress,
                tokensGiven
            );
            return false;
        }

        // Check Cash Recieved with Composition Calculator
        uint256 _tokensRecieved = compositionCalculator
            .getCurrentCashAmountCreatedByToken(tokensGiven, executionPrice);
        require(
            _tokensRecieved == tokensRecieved,
            "cash redeemed must equal tokens recieved"
        );

        // Save To Storage
        persistentStorage.setOrderByUser(
            whitelistedAddress,
            "REDEEM",
            tokensGiven,
            tokensRecieved,
            avgBlendedFee,
            0,
            false
        );

        // Redeem Stablecoin or Perform Delayed Settlement
        redeemFunds(tokensGiven, tokensRecieved, whitelistedAddress);

        // Burn Tokens to Address
        InterfaceInverseToken token = InterfaceInverseToken(inverseToken);
        token.burnTokens(address(cashPool), tokensGiven);

        return true;
    }

    function writeOrderResponse(
        string memory orderType,
        address whiteListedAddress,
        uint256 tokensGiven,
        uint256 tokensRecieved
    ) internal {
        require(
            tokensGiven != 0 && tokensRecieved != 0,
            "amount must be greater than 0"
        );

        emit SuccessfulOrder(
            orderType,
            whiteListedAddress,
            tokensGiven,
            tokensRecieved
        );
    }

    function settleDelayedFunds(
        uint256 tokensToRedeem,
        address whitelistedAddress
    ) public onlyOwnerOrBridge notPausedOrShutdown {
        require(
            kycVerifier.isAddressWhitelisted(whitelistedAddress),
            "only whitelisted may redeem funds"
        );

        bool isSufficientFunds = isHotWalletSufficient(tokensToRedeem);
        require(
            isSufficientFunds == true,
            "not enough funds in the hot wallet"
        );

        uint256 tokensOutstanding = persistentStorage.delayedRedemptionsByUser(
            whitelistedAddress
        );
        uint256 tokensRemaining = DSMath.sub(tokensOutstanding, tokensToRedeem);

        persistentStorage.setDelayedRedemptionsByUser(
            tokensRemaining,
            whitelistedAddress
        );
        transferTokenFromPool(
            stablecoin,
            whitelistedAddress,
            normalizeUSDC(tokensToRedeem)
        );
    }

    function redeemFunds(
        uint256 tokensGiven,
        uint256 tokensToRedeem,
        address whitelistedAddress
    ) internal {
        bool isSufficientFunds = isHotWalletSufficient(tokensToRedeem);

        if (isSufficientFunds) {
            transferTokenFromPool(
                stablecoin,
                whitelistedAddress,
                normalizeUSDC(tokensToRedeem)
            );
            writeOrderResponse(
                "REDEEM",
                whitelistedAddress,
                tokensGiven,
                tokensToRedeem
            );
        } else {
            uint256 tokensOutstanding = persistentStorage
                .delayedRedemptionsByUser(whitelistedAddress);
            tokensOutstanding = DSMath.add(tokensOutstanding, tokensToRedeem);
            persistentStorage.setDelayedRedemptionsByUser(
                tokensOutstanding,
                whitelistedAddress
            );
            writeOrderResponse(
                "REDEEM_NO_SETTLEMENT",
                whitelistedAddress,
                tokensGiven,
                tokensToRedeem
            );
        }
    }

    function isHotWalletSufficient(uint256 tokensToRedeem)
        internal
        view
        returns (bool)
    {
        InterfaceInverseToken _stablecoin = InterfaceInverseToken(stablecoin);
        uint256 stablecoinBalance = _stablecoin.balanceOf(address(cashPool));

        if (normalizeUSDC(tokensToRedeem) > stablecoinBalance) return false;
        return true;
    }

    function normalizeUSDC(uint256 usdcValue) public pure returns (uint256) {
        return usdcValue / 10**12;
    }

    ////////////////    Daily Rebalance     ////////////////
    //////////////// Threshold Rebalance    ////////////////

    function _dailyRebalance(
        uint256 _price,
        uint256 _lendingFeeCalc,
        uint256 _endCashPosition,
        uint256 _endBalance,
        uint256 _totalTokenSupply
    ) internal view returns (uint256, uint256) {
        // Rebalance Inputs : Trade Execution Price + Updated Loan Positions (repaid and outstanding)
        // Rebalance Outputs : Cash Pool Adjustment + Updated PCF (calculated through CompositionCalculator.sol)
        // Cash Pool Adjustment Handled Through Helper Functions Below
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

        uint256 cashPositionPerTokenUnit = DSMath.wdiv(
            endCashPosition,
            totalTokenSupply
        );
        uint256 balancePerTokenUnit = DSMath.wdiv(endBalance, totalTokenSupply);

        return (cashPositionPerTokenUnit, balancePerTokenUnit);
    }

    /**
     * @dev Sets the accounting of today for the curent price
     * @param _price The momentary price of the crypto
     * @param _totalFee The total fees
     * @param _lendingFee The blended lending fee of the balance
     * @param _endCashPosition The total cashpostion on the product
     * @param _endBalance The total dept on the product
     * @param _totalTokenSupply The token supply with witch expected
     */
    function dailyRebalance(
        uint256 _price,
        uint256 _totalFee,
        uint256 _lendingFee,
        uint256 _endCashPosition,
        uint256 _endBalance,
        uint256 _totalTokenSupply
    ) public onlyOwnerOrBridge() notPausedOrShutdown() {
        // Rebalance Inputs : Trade Execution Price + Updated Loan Positions (repaid and outstanding)
        // Rebalance Outputs : Cash Pool Adjustment + Updated PCF (calculated through CompositionCalculator.sol)
        // Collater Pool Adjustment Handled Through Helper Functions Below
        (
            uint256 cashPositionPerTokenUnit,
            uint256 balancePerTokenUnit
        ) = _dailyRebalance(
            _price,
            _totalFee,
            _endCashPosition,
            _endBalance,
            _totalTokenSupply
        );
        persistentStorage.setAccounting(
            _price,
            cashPositionPerTokenUnit,
            balancePerTokenUnit,
            _lendingFee
        );
        emit RebalanceEvent(
            _price,
            cashPositionPerTokenUnit,
            balancePerTokenUnit,
            _lendingFee
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
    ) public onlyOwnerOrBridge() notPausedOrShutdown() {
        // First Sanity Check Threshold Crossing
        // Rebalance Inputs : Trade Execution Price + Updated Loan Positions (repaid and outstanding)
        // Rebalance Outputs : Cash Pool Adjustment + Updated PCF (calculated through CompositionCalculator.sol)
        // Cash Pool Adjustment Handled Through Helper Functions Below
        (
            uint256 cashPositionPerTokenUnit,
            uint256 balancePerTokenUnit
        ) = _dailyRebalance(
            _price,
            0,
            _endCashPosition,
            _endBalance,
            _totalTokenSupply
        );
        persistentStorage.setAccountingForLastActivityDay(
            _price,
            cashPositionPerTokenUnit,
            balancePerTokenUnit,
            _lendingFee
        );
        emit RebalanceEvent(
            _price,
            cashPositionPerTokenUnit,
            balancePerTokenUnit,
            _lendingFee
        );
    }

    //////////////// Transfer Stablecoin Out of Pool   ////////////////
    //////////////// Transfer Stablecoin In of Pool    ////////////////
    //////////////// Transfer InverseToken Out of Pool ////////////////
    //////////////// Transfer InverseToken In of Pool  ////////////////

    function transferTokenToPool(
        address tokenContract,
        address whiteListedAddress,
        uint256 orderAmount
    ) internal returns (bool) {
        // Check orderAmount <= availableAmount
        // Transfer USDC to Stablecoin Cash Pool
        return
            cashPool.moveTokenToPool(
                tokenContract,
                whiteListedAddress,
                orderAmount
            );
    }

    function transferTokenFromPool(
        address tokenContract,
        address destinationAddress,
        uint256 orderAmount
    ) internal returns (bool) {
        // Check orderAmount <= availableAmount
        // Transfer USDC to Destination Address
        return
            cashPool.moveTokenfromPool(
                tokenContract,
                destinationAddress,
                orderAmount
            );
    }

    modifier onlyOwnerOrBridge() {
        require(
            isOwner() || _msgSender() == persistentStorage.bridge(),
            "caller is not the owner or bridge"
        );
        _;
    }

    modifier notPausedOrShutdown() {
        require(persistentStorage.isPaused() == false, "contract is paused");
        require(
            persistentStorage.isShutdown() == false,
            "contract is shutdown"
        );
        _;
    }
}
