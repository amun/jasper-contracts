pragma solidity ^0.5.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "./utils/Math.sol";
import "./utils/DateTimeLibrary.sol";
import "./PersistentStorage.sol";
import "./Abstract/InterfaceInverseToken.sol";

/**
 * @dev uint256 are expected to use last 18 numbers as decimal points except when specifid differently in @params
 */
contract CompositionCalculator is Initializable {
    using SafeMath for uint256;

    PersistentStorage public persistentStorage;
    InterfaceInverseToken public inverseToken;

    function initialize(
        address _persistentStorageAddress,
        address _inverseTokenAddress
    ) public initializer {
        persistentStorage = PersistentStorage(_persistentStorageAddress);
        inverseToken = InterfaceInverseToken(_inverseTokenAddress);
    }

    //*************************************************************************
    //************************** Pure Functions *******************************
    //*************************************************************************

    /**
     * @dev Returns NAV for the given values
     * @param _cashPosition The yearly average lending fee for borrowed balance
     * @param _balance The balnce (dept/borrow) in crypto
     * @param _price The momentary price of the crypto
     */
    function getNAV(uint256 _cashPosition, uint256 _balance, uint256 _price)
        public
        pure
        returns (uint256 nav)
    {
        // Calculate NAV of Product
        uint256 balanceWorth = DSMath.wmul(_balance, _price);
        require(
            _cashPosition > balanceWorth,
            "The cash position needs to be bigger then the borrowed crypto is worth"
        );
        nav = DSMath.sub(_cashPosition, balanceWorth);
        return nav;
    }

    /**
     * @dev Returns the crypto amount to pay as lending fee
     * @param _lendingFee The yearly average lending fee for borrowed balance
     * @param _balance The balnce (dept/borrow) in crypto
     * @param _days The days since the last fee calculation (Natural number)
     */
    function getLendingFeeInCrypto(
        uint256 _lendingFee,
        uint256 _balance,
        uint256 _days
    ) public pure returns (uint256 feeInCrypto) {
        uint256 lendingFeePercent = DSMath.wdiv(_lendingFee, 100 ether);
        uint256 feePerDay = DSMath.wdiv(lendingFeePercent, 365 ether);
        uint256 feeInCryptoForOneDay = DSMath.wmul(feePerDay, _balance);
        feeInCrypto = DSMath.mul(_days, feeInCryptoForOneDay);
    }

    /**
     * Returns the change of balance with decimal at 18
     * @param _nav The current nav of the product
     * @param _balance The balnce (dept/borrow) in crypto
     * @param _price The momentary price of the crypto
     */
    function getNeededChangeInBalanceToRebalance(
        uint256 _nav,
        uint256 _balance,
        uint256 _price
    ) public pure returns (uint256 changeInBalance, bool negative) {
        require(_price != 0, "Price cant be zero");

        uint256 newAcountBalance = DSMath.wdiv(_nav, _price);

        if (newAcountBalance >= _balance) {
            changeInBalance = DSMath.sub(newAcountBalance, _balance);
            negative = false;
        } else {
            changeInBalance = DSMath.sub(_balance, newAcountBalance);
            negative = true;
        }
    }

    /**
     * @param _a First number
     * @param _b Second number
     * @param _isBNegative Is number b negative
     */
    function addOrSub(
        //getDeliverables
        uint256 _a,
        uint256 _b,
        bool _isBNegative
    ) internal pure returns (uint256 result) {
        if (_isBNegative) {
            return _a.sub(_b);
        } else {
            return _a.add(_b);
        }
    }

    /**
     * @dev Returns imported values for a PCF
     * @param _cashPosition The total cash position on the token
     * @param _balance The balance (dept/borrow) in crypto
     * @param _price The momentary price of the crypto
     * @param _lendingFee The yearly average lending fee for borrowed balance
     * @param _days The days since the last fee calculation  (Natural number)
     * @param _minRebalanceAmount The minimum amount to rebalance
     */
    function calculatePCF(
        uint256 _cashPosition,
        uint256 _balance,
        uint256 _price,
        uint256 _lendingFee,
        uint256 _days,
        uint256 _minRebalanceAmount
    )
        public
        pure
        returns (
            uint256 endNav,
            uint256 endBalance,
            uint256 endCashPosition,
            uint256 feeInFiat,
            uint256 changeInBalance,
            bool isChangeInBalanceNeg
        )
    {
        require(_price != 0, "Price cant be zero");
        // Update Calculation for NAV, Cash Position, Loan Positions, and Accrued Fees

        //remove fees
        uint256 feeInCrypto = getLendingFeeInCrypto(
            _lendingFee,
            _balance,
            _days
        );
        require(
            feeInCrypto <= _balance,
            "The balance cant be smaller then the fee"
        );

        feeInFiat = DSMath.wmul(feeInCrypto, _price);

        //cashPositionWithoutFee
        endCashPosition = DSMath.sub(_cashPosition, feeInFiat);

        //calculte change in balance (rebalance)
        endBalance = DSMath.wdiv(
            getNAV(endCashPosition, _balance, _price),
            _price
        );

        (
            changeInBalance,
            isChangeInBalanceNeg
        ) = getNeededChangeInBalanceToRebalance(
            getNAV(endCashPosition, _balance, _price),
            _balance,
            _price
        );

        if (changeInBalance < _minRebalanceAmount) {
            changeInBalance = 0;
            endBalance = _balance;
        }

        //result
        endCashPosition = addOrSub(
            endCashPosition, //cashPositionWithoutFee
            DSMath.wmul(changeInBalance, _price),
            isChangeInBalanceNeg
        );
        endNav = getNAV(endCashPosition, endBalance, _price);
    }

    /**
     * @param _cashPosition The total cash position on the token
     * @param _balance The balance (dept/borrow) in crypto
     * @param _price The momentary price of the crypto
     * @param _lendingFee The yearly average lending fee for borrowed balance
     * @param _days The days since the last fee calculation (Natural number)
     */
    function calculatePCFWithoutMin(
        //getDeliverables
        uint256 _cashPosition,
        uint256 _balance,
        uint256 _price,
        uint256 _lendingFee,
        uint256 _days
    )
        public
        pure
        returns (
            uint256 endNav,
            uint256 endBalance,
            uint256 endCashPosition,
            uint256 feeInFiat,
            uint256 changeInBalance,
            bool isChangeInBalanceNeg
        )
    {
        return
            calculatePCF(
                _cashPosition,
                _balance,
                _price,
                _lendingFee,
                _days,
                0
            );
    }

    /**
     * @dev Returns the amount of token created by cash at price
     * @param _cashPosition The total cash position on the token
     * @param _balance The balance (dept/borrow) in crypto
     * @param _totalTokenSupply The total token supply
     * @param _cash The cash provided to create token
     * @param _spotPrice The momentary price of the crypto
     */
    function getTokenAmountCreatedByCash(
        //Create
        uint256 _cashPosition,
        uint256 _balance,
        uint256 _totalTokenSupply,
        uint256 _cash,
        uint256 _spotPrice
    ) public pure returns (uint256 tokenAmountCreated) {
        require(_spotPrice != 0, "Price cant be zero");
        require(_totalTokenSupply != 0, "Token supply cant be zero");

        uint256 exNav = getNAV(_cashPosition, _balance, _spotPrice);
        uint256 navPerToken = DSMath.wdiv(exNav, _totalTokenSupply);
        tokenAmountCreated = DSMath.wdiv(_cash, navPerToken);
    }

    /**
     * @dev Returns the amount of cash redeemed at price
     * @param _cashPosition The total cash position on the token
     * @param _balance The balance (dept/borrow) in crypto
     * @param _totalTokenSupply The total token supply
     * @param _tokenAmount The token provided to redeem cash
     * @param _spotPrice The momentary price of the crypto
     */
    function getCashAmountCreatedByToken(
        //Redeem
        uint256 _cashPosition,
        uint256 _balance,
        uint256 _totalTokenSupply,
        uint256 _tokenAmount,
        uint256 _spotPrice
    ) public pure returns (uint256 cashFromTokenRedeem) {
        require(_spotPrice != 0, "Price cant be zero");
        require(_totalTokenSupply != 0, "Token supply cant be zero");
        require(
            _totalTokenSupply >= _tokenAmount,
            "Token redeem cant be bigger then supply"
        );

        uint256 exNav = getNAV(_cashPosition, _balance, _spotPrice);
        uint256 navPerToken = DSMath.wdiv(exNav, _totalTokenSupply);

        cashFromTokenRedeem = DSMath.wmul(_tokenAmount, navPerToken);
    }

    /**
     * @dev Returns cash without fee
     * @param _cash The cash provided to create token
     * @param _mintingFee The minting fee to remove
     */
    function removeMintingFeeFromCash(uint256 _cash, uint256 _mintingFee)
        public
        pure
        returns (uint256 cashAfterFee)
    {
        uint256 creationFeeInCash = DSMath.wmul(_cash, _mintingFee);
        cashAfterFee = DSMath.sub(_cash, creationFeeInCash);
    }

    //*************************************************************************
    //***************** Get values for last PCF *******************************
    //*************************************************************************

    /**
     * @dev Returns the current NAV
     */
    function getCurrentNAV() public view returns (uint256 nav) {
        uint256 totalTokenSupply = inverseToken.totalSupply();
        require(totalTokenSupply != 0, "Token supply cant be zero");

        uint256 cashPosition = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getCashPositionPerToken()
        );
        uint256 balance = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getBalancePerToken()
        );
        uint256 price = persistentStorage.getPrice();

        nav = getNAV(cashPosition, balance, price);
    }

    /**
     * @dev Returns cash without fee
     * @param _cash The cash provided to create token
     */
    function removeCurrentMintingFeeFromCash(uint256 _cash)
        public
        view
        returns (uint256 cashAfterFee)
    {
        uint256 creationFee = persistentStorage.getMintingFee(_cash);
        cashAfterFee = removeMintingFeeFromCash(_cash, creationFee);
    }

    /**
     * @dev Returns the amount of token created by cash
     * @param _cash The cash provided to create token
     * @param _spotPrice The momentary price of the crypto
     */
    function getCurrentTokenAmountCreatedByCash(
        //Create
        uint256 _cash,
        uint256 _spotPrice
    ) public view returns (uint256 tokenAmountCreated) {
        uint256 totalTokenSupply = inverseToken.totalSupply();
        require(totalTokenSupply != 0, "Token supply cant be zero");
        uint256 cashPosition = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getCashPositionPerToken()
        );

        uint256 cashAfterFee = removeCurrentMintingFeeFromCash(_cash);
        uint256 balance = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getBalancePerToken()
        );
        tokenAmountCreated = getTokenAmountCreatedByCash(
            cashPosition,
            balance,
            totalTokenSupply,
            cashAfterFee,
            _spotPrice
        );
    }

    /**
     * @dev Returns the amount of cash redeemed at spot price
     * @param _tokenAmount The token provided to redeem cash
     * @param _spotPrice The momentary price of the crypto
     */
    function getCurrentCashAmountCreatedByToken(
        //Redeem
        uint256 _tokenAmount,
        uint256 _spotPrice
    ) public view returns (uint256 cashFromTokenRedeem) {
        uint256 totalTokenSupply = inverseToken.totalSupply();
        require(totalTokenSupply != 0, "Token supply cant be zero");

        uint256 cashPosition = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getCashPositionPerToken()
        );
        uint256 balance = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getBalancePerToken()
        );
        uint256 cashFromToken = getCashAmountCreatedByToken(
            cashPosition,
            balance,
            totalTokenSupply,
            _tokenAmount,
            _spotPrice
        );
        cashFromTokenRedeem = removeCurrentMintingFeeFromCash(cashFromToken);
    }

    function getDaysSinceLastRebalance()
        public
        view
        returns (uint256 daysSinceLastRebalance)
    {
        uint256 lastRebalanceDay = persistentStorage.lastActivityDay();
        uint256 year = lastRebalanceDay.div(10000);
        uint256 month = lastRebalanceDay.div(100) - year.mul(100);
        uint256 day = lastRebalanceDay - year.mul(10000) - month.mul(100);

        uint256 startDate = DateTimeLibrary.timestampFromDate(year, month, day);
        daysSinceLastRebalance = (now - startDate) / 60 / 60 / 24;
    }

    /**
     * @dev Returns the lending fee in crypto
     */
    function getCurrentLendingFeeInCrypto()
        public
        view
        returns (uint256 cryptoForLendingFee)
    {
        uint256 totalTokenSupply = inverseToken.totalSupply();
        uint256 lendingFee = persistentStorage.getLendingFee();
        uint256 balance = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getBalancePerToken()
        );
        uint256 daysSinceLastRebalance = getDaysSinceLastRebalance();

        cryptoForLendingFee = getLendingFeeInCrypto(
            lendingFee,
            balance,
            daysSinceLastRebalance
        );
    }

    /**
     * @dev Returns balance change needed to perform to have a balanced cashposition to balance ratio
     */
    function getCurrentNeededChangeInBalanceToRebalance(uint256 _price)
        public
        view
        returns (uint256 neededChangeInBalance, bool isNegative)
    {
        uint256 totalTokenSupply = inverseToken.totalSupply();
        uint256 nav = getCurrentNAV();
        uint256 balance = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getBalancePerToken()
        );
        return getNeededChangeInBalanceToRebalance(nav, balance, _price);
    }

    /**
     * @dev Returns total balance
     */
    function getTotalBalance() external view returns (uint256 totalBalance) {
        uint256 totalTokenSupply = inverseToken.totalSupply();
        totalBalance = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getBalancePerToken()
        );
        return totalBalance;
    }

    /**
     * @dev Returns current PCF values for the given price
     * @param _price The momentary price of the crypto
     */
    function calculateDailyPCF(uint256 _price, uint256 _lendingFee)
        public
        view
        returns (
            uint256 endNav,
            uint256 endBalance,
            uint256 endCashPosition,
            uint256 feeInFiat,
            uint256 changeInBalance,
            bool isChangeInBalanceNeg
        )
    {
        require(_price != 0, "Price cant be zero");
        uint256 totalTokenSupply = inverseToken.totalSupply();
        uint256 balance = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getBalancePerToken()
        );
        uint256 cashPosition = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getCashPositionPerToken()
        );
        uint256 daysSinceLastRebalance = getDaysSinceLastRebalance();
        uint256 minRebalanceAmount = persistentStorage.minRebalanceAmount();

        return
            calculatePCF(
                cashPosition,
                balance,
                _price,
                _lendingFee,
                daysSinceLastRebalance,
                minRebalanceAmount
            );
    }

    /**
     * @dev Returns total cash position
     */
    function getTotalCashPosition()
        public
        view
        returns (uint256 totalCashPosition)
    {
        uint256 totalTokenSupply = inverseToken.totalSupply();
        totalCashPosition = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getCashPositionPerToken()
        );
    }
    function wmul(uint256 x, uint256 y) external pure returns (uint256 z) {
        z = DSMath.wmul(x, y);
    }

    function wdiv(uint256 x, uint256 y) external pure returns (uint256 z) {
        z = DSMath.wdiv(x, y);
    }

}
