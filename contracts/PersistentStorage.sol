pragma solidity ^0.5.0;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./utils/DateTimeLibrary.sol";
import "./utils/Math.sol";


contract PersistentStorage is Ownable {
    address public tokenSwapManager;
    address public bridge;

    bool public isPaused;
    bool public isShutdown;

    struct Accounting {
        uint256 price;
        uint256 cashPositionPerTokenUnit;
        uint256 balancePerTokenUnit;
        uint256 lendingFee;
    }

    struct Order {
        string orderType;
        uint256 tokensGiven;
        uint256 tokensRecieved;
        uint256 avgBlendedFee;
    }

    uint256 public lastActivityDay;
    uint256 public minRebalanceAmount;
    uint256 public managementFee;
    uint8 public balancePrecision;

    mapping(uint256 => Accounting[]) private accounting;

    mapping(address => bool) public whitelistedAddresses;

    uint256[] public mintingFeeBracket;
    mapping(uint256 => uint256) public mintingFee;

    Order[] public allOrders;
    mapping(address => Order[]) public orderByUser;
    mapping(address => uint256) public delayedRedemptionsByUser;

    event AccountingValuesSet(uint256 today);
    event RebalanceValuesSet(uint256 newMinRebalanceAmount);
    event ManagementFeeValuesSet(uint256 newManagementFee);

    function initialize(
        address ownerAddress,
        uint256 _managementFee,
        uint256 _minRebalanceAmount
    ) public initializer {
        initialize(ownerAddress);
        managementFee = _managementFee;
        minRebalanceAmount = _minRebalanceAmount;
        mintingFeeBracket.push(50000 ether);
        mintingFeeBracket.push(100000 ether);
        mintingFee[50000 ether] = 3 ether / 1000; //0.3%
        mintingFee[100000 ether] = 2 ether / 1000; //0.2%
        mintingFee[~uint256(0)] = 1 ether / 1000; //0.1% all values higher
        balancePrecision = 10;
    }

    function setTokenSwapManager(address _tokenSwapManager) public onlyOwner {
        require(_tokenSwapManager != address(0), "adddress must not be empty");
        tokenSwapManager = _tokenSwapManager;
    }

    function setBridge(address _bridge) public onlyOwner {
        require(_bridge != address(0), "adddress must not be empty");
        bridge = _bridge;
    }

    function setIsPaused(bool _isPaused) public onlyOwner {
        isPaused = _isPaused;
    }

    function shutdown() public onlyOwner {
        isShutdown = true;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwnerOrTokenSwap() {
        require(
            isOwner() || _msgSender() == tokenSwapManager,
            "caller is not the owner or token swap manager"
        );
        _;
    }

    function setDelayedRedemptionsByUser(
        uint256 amountToRedeem,
        address whitelistedAddress
    ) public onlyOwnerOrTokenSwap {
        delayedRedemptionsByUser[whitelistedAddress] = amountToRedeem;
    }

    /*
     * Saves order in mapping (address => Order[]) orderByUser
     * overwrite == false, append to Order[]
     * overwrite == true, overwrite element at orderIndex
     */

    function setOrderByUser(
        address whitelistedAddress,
        string memory orderType,
        uint256 tokensGiven,
        uint256 tokensRecieved,
        uint256 avgBlendedFee,
        uint256 orderIndex,
        bool overwrite
    ) public onlyOwnerOrTokenSwap() {
        Order memory newOrder = Order(
            orderType,
            tokensGiven,
            tokensRecieved,
            avgBlendedFee
        );

        if (!overwrite) {
            orderByUser[whitelistedAddress].push(newOrder);
            setOrder(
                orderType,
                tokensGiven,
                tokensRecieved,
                avgBlendedFee,
                orderIndex,
                overwrite
            );
        } else {
            orderByUser[whitelistedAddress][orderIndex] = newOrder;
        }
    }

    /*
     * Gets Order[] For User Address
     * Return order at Index in Order[]
     */

    function getOrderByUser(address whitelistedAddress, uint256 orderIndex)
        public
        view
        returns (
            string memory orderType,
            uint256 tokensGiven,
            uint256 tokensRecieved,
            uint256 avgBlendedFee
        )
    {

            Order storage orderAtIndex
         = orderByUser[whitelistedAddress][orderIndex];
        return (
            orderAtIndex.orderType,
            orderAtIndex.tokensGiven,
            orderAtIndex.tokensRecieved,
            orderAtIndex.avgBlendedFee
        );
    }

    /*
     * Save order to allOrders array
     * overwrite == false, append to allOrders array
     * overwrite == true, overwrite element at orderIndex
     */
    function setOrder(
        string memory orderType,
        uint256 tokensGiven,
        uint256 tokensRecieved,
        uint256 avgBlendedFee,
        uint256 orderIndex,
        bool overwrite
    ) public onlyOwnerOrTokenSwap() {
        Order memory newOrder = Order(
            orderType,
            tokensGiven,
            tokensRecieved,
            avgBlendedFee
        );

        if (!overwrite) {
            allOrders.push(newOrder);
        } else {
            allOrders[orderIndex] = newOrder;
        }
    }

    /*
     * Get Order
     */
    function getOrder(uint256 index)
        public
        view
        returns (
            string memory orderType,
            uint256 tokensGiven,
            uint256 tokensRecieved,
            uint256 avgBlendedFee
        )
    {
        Order storage orderAtIndex = allOrders[index];
        return (
            orderAtIndex.orderType,
            orderAtIndex.tokensGiven,
            orderAtIndex.tokensRecieved,
            orderAtIndex.avgBlendedFee
        );
    }

    // @dev Set whitelisted addresses
    function setWhitelistedAddress(address adddressToAdd) public onlyOwner {
        require(adddressToAdd != address(0), "adddress must not be empty");

        whitelistedAddresses[adddressToAdd] = true;
    }

    // @dev Remove whitelisted addresses
    function removeWhitelistedAddress(address addressToRemove)
        public
        onlyOwner
    {
        require(
            whitelistedAddresses[addressToRemove],
            "address must be added to be removed allowed"
        );

        delete whitelistedAddresses[addressToRemove];
    }

    // @dev Updates whitelisted addresses
    function updateWhitelistedAddress(address oldAddress, address newAddress)
        public
    {
        removeWhitelistedAddress(oldAddress);
        setWhitelistedAddress(newAddress);
    }

    // @dev Get accounting values for a specific day
    // @param date format as 20200123 for 23th of January 2020
    function getAccounting(uint256 date)
        public
        view
        returns (uint256, uint256, uint256, uint256)
    {
        return (
            accounting[date][accounting[date].length - 1].price,
            accounting[date][accounting[date].length - 1]
                .cashPositionPerTokenUnit,
            accounting[date][accounting[date].length - 1].balancePerTokenUnit,
            accounting[date][accounting[date].length - 1].lendingFee
        );
    }

    // @dev Set accounting values for the day
    function setAccounting(
        uint256 _price,
        uint256 _cashPositionPerTokenUnit,
        uint256 _balancePerTokenUnit,
        uint256 _lendingFee
    ) external onlyOwnerOrTokenSwap() {
        (uint256 year, uint256 month, uint256 day) = DateTimeLibrary
            .timestampToDate(block.timestamp);
        uint256 today = year * 10000 + month * 100 + day;
        accounting[today].push(
            Accounting(
                _price,
                _cashPositionPerTokenUnit,
                _balancePerTokenUnit,
                _lendingFee
            )
        );
        lastActivityDay = today;
        emit AccountingValuesSet(today);
    }

    // @dev Set accounting values for the day
    function setAccountingForLastActivityDay(
        uint256 _price,
        uint256 _cashPositionPerTokenUnit,
        uint256 _balancePerTokenUnit,
        uint256 _lendingFee
    ) external onlyOwnerOrTokenSwap() {
        accounting[lastActivityDay].push(
            Accounting(
                _price,
                _cashPositionPerTokenUnit,
                _balancePerTokenUnit,
                _lendingFee
            )
        );
        emit AccountingValuesSet(lastActivityDay);
    }

    // @dev Set last rebalance information
    function setMinRebalanceAmount(uint256 _minRebalanceAmount)
        external
        onlyOwner
    {
        minRebalanceAmount = _minRebalanceAmount;

        emit RebalanceValuesSet(minRebalanceAmount);
    }

    // @dev Set last rebalance information
    function setManagementFee(uint256 _managementFee) external onlyOwner {
        managementFee = _managementFee;
        emit ManagementFeeValuesSet(managementFee);
    }

    // @dev Returns price
    function getPrice() public view returns (uint256 price) {
        return
            accounting[lastActivityDay][accounting[lastActivityDay].length - 1]
                .price;
    }

    // @dev Returns cash position amount
    function getCashPositionPerTokenUnit()
        public
        view
        returns (uint256 amount)
    {
        return
            accounting[lastActivityDay][accounting[lastActivityDay].length - 1]
                .cashPositionPerTokenUnit;
    }

    // @dev Returns borrowed crypto amount
    function getBalancePerTokenUnit() public view returns (uint256 amount) {
        return
            accounting[lastActivityDay][accounting[lastActivityDay].length - 1]
                .balancePerTokenUnit;
    }

    // @dev Returns lending fee
    function getLendingFee() public view returns (uint256 lendingRate) {
        return
            accounting[lastActivityDay][accounting[lastActivityDay].length - 1]
                .lendingFee;
    }

    // @dev Sets last minting fee
    function setLastMintingFee(uint256 _mintingFee) public onlyOwner {
        mintingFee[~uint256(0)] = _mintingFee;
    }

    // @dev Adds minting fee
    function addMintingFeeBracket(uint256 _mintingFeeLimit, uint256 _mintingFee)
        public
        onlyOwner
    {
        require(
            _mintingFeeLimit > mintingFeeBracket[mintingFeeBracket.length - 1],
            "New minting fee bracket needs to be bigger then last one"
        );
        mintingFeeBracket.push(_mintingFeeLimit);
        mintingFee[_mintingFeeLimit] = _mintingFee;
    }

    // @dev Deletes last minting fee
    function deleteLastMintingFeeBracket() public onlyOwner {
        delete mintingFee[mintingFeeBracket[mintingFeeBracket.length - 1]];
        mintingFeeBracket.length--;
    }

    // @dev Changes minting fee
    function changeMintingLimit(
        uint256 _position,
        uint256 _mintingFeeLimit,
        uint256 _mintingFee
    ) public onlyOwner {
        require(
            _mintingFeeLimit > mintingFeeBracket[mintingFeeBracket.length - 1],
            "New minting fee bracket needs to be bigger then last one"
        );
        if (_position != 0) {
            require(
                _mintingFeeLimit > mintingFeeBracket[_position - 1],
                "New minting fee bracket needs to be bigger then last one"
            );
        }
        if (_position < mintingFeeBracket.length - 1) {
            require(
                _mintingFeeLimit < mintingFeeBracket[_position + 1],
                "New minting fee bracket needs to be smaller then next one"
            );
        }
        mintingFeeBracket[_position] = _mintingFeeLimit;
        mintingFee[_mintingFeeLimit] = _mintingFee;
    }

    function getMintingFee(uint256 cash) public view returns (uint256) {
        // Define Start + End Index
        uint256 startIndex = 0;
        uint256 endIndex = mintingFeeBracket.length - 1;
        uint256 middleIndex = endIndex / 2;

        if (cash <= mintingFeeBracket[middleIndex]) {
            endIndex = middleIndex;
        } else {
            startIndex = middleIndex + 1;
        }

        for (uint256 i = startIndex; i <= endIndex; i++) {
            if (cash <= mintingFeeBracket[i]) {
                return mintingFee[mintingFeeBracket[i]];
            }
        }
        return mintingFee[~uint256(0)];
    }

    // @dev Sets last balance precision
    function setLastPrecision(uint8 _balancePrecision) public onlyOwner {
        balancePrecision = _balancePrecision;
    }
}
