pragma solidity ^0.5.0;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./Abstract/InterfaceInverseToken.sol";
import "./Abstract//InterfaceKYCVerifier.sol";


contract CashPool is Ownable {
    using SafeMath for uint256;
    InterfaceKYCVerifier public kycVerifier;

    uint256[2] public percentageOfFundsForColdStorage;
    address public coldStorage;

    mapping(address => bool) public approvedTokenManagers;

    event SetPercentageOfFundsForColdStorageEvent(
        uint256[2] newPercentageOfFundsForColdStorage
    );

    function initialize(
        address ownerAddress,
        address _kycVerifier,
        address _coldStorage,
        uint256[2] memory _percentageOfFundsForColdStorage
    ) public initializer {
        require(
            ownerAddress != address(0) &&
                _kycVerifier != address(0) &&
                _coldStorage != address(0) &&
                _percentageOfFundsForColdStorage[1] != 0,
            "params variables cannot be empty but _percentageOfFundsForColdStorage[0]"
        );
        require(
            _percentageOfFundsForColdStorage[0] <=
                _percentageOfFundsForColdStorage[1],
            "cannot set more than 100% for coldstorage"
        );
        initialize(ownerAddress);
        kycVerifier = InterfaceKYCVerifier(_kycVerifier);
        coldStorage = _coldStorage;
        percentageOfFundsForColdStorage = _percentageOfFundsForColdStorage;
    }

    function getBalance(address _token) public view returns (uint256) {
        InterfaceInverseToken token_ = InterfaceInverseToken(_token);
        uint256 tokenBalance = token_.balanceOf(address(this));
        return tokenBalance;
    }

    // @dev Sets new coldStorage
    // @param _newColdStorage Address for new cold storage wallet
    function setColdStorage(address _newColdStorage) public onlyOwner {
        require(_newColdStorage != address(0), "address cannot be empty");
        coldStorage = _newColdStorage;
    }

    // @dev Sets percentage of funds to stay in contract. Owner only
    // @param _newPercentageOfFundsForColdStorage List with two elements referencing percentage of funds for cold storage as a fraction
    // e.g. 1/2 is [1,2]
    function setPercentageOfFundsForColdStorage(
        uint256[2] memory _newPercentageOfFundsForColdStorage
    ) public onlyOwner {
        require(
            _newPercentageOfFundsForColdStorage[1] != 0,
            "denominator should not be zero"
        );
        require(
            _newPercentageOfFundsForColdStorage[0] <=
                _newPercentageOfFundsForColdStorage[1],
            "cannot set more than 100% for coldstorage"
        );
        percentageOfFundsForColdStorage[0] = _newPercentageOfFundsForColdStorage[0];
        percentageOfFundsForColdStorage[1] = _newPercentageOfFundsForColdStorage[1];

        emit SetPercentageOfFundsForColdStorageEvent(
            _newPercentageOfFundsForColdStorage
        );
    }

    // ############################################## Add/Remove ############################################## //
    // ############################################## Token ################################################### //
    // ############################################## Manager ################################################# //

    function addTokenManager(address tokenManager) public onlyOwner {
        require(tokenManager != address(0), "adddress must not be empty");
        approvedTokenManagers[tokenManager] = true;
    }

    function removeTokenManager(address tokenManager) public onlyOwner {
        require(tokenManager != address(0), "adddress must not be empty");
        delete approvedTokenManagers[tokenManager];
    }

    function isTokenManager(address potentialAddress)
        public
        view
        returns (bool)
    {
        require(potentialAddress != address(0), "adddress must not be empty");
        return approvedTokenManagers[potentialAddress];
    }

    modifier onlyOwnerOrTokenSwap() {
        require(
            isOwner() || approvedTokenManagers[_msgSender()] == true,
            "caller is not the owner or an approved token swap manager"
        );
        _;
    }

    // @dev Move tokens out of cash pool
    // @param _token ERC20 address
    // @param destinationAddress address to send to
    // @param orderAmount amount to transfer from cash pool
    function moveTokenfromPool(
        address _token,
        address destinationAddress,
        uint256 orderAmount
    ) public onlyOwnerOrTokenSwap() returns (bool) {
        InterfaceInverseToken token_ = InterfaceInverseToken(_token);

        token_.transfer(destinationAddress, orderAmount);
        return true;
    }

    // @dev Move tokens to cash pool
    // @param _token ERC20 address
    // @param whiteListedAddress address allowed to transfer to pool
    // @param orderAmount amount to transfer to cash pool
    function moveTokenToPool(
        address _token,
        address whiteListedAddress,
        uint256 orderAmount
    ) public onlyOwnerOrTokenSwap() returns (bool) {
        InterfaceInverseToken token_ = InterfaceInverseToken(_token);
        require(
            kycVerifier.isAddressWhitelisted(whiteListedAddress),
            "only whitelisted address are allowed to move tokens to pool"
        );

        uint256 percentageNumerator = percentageOfFundsForColdStorage[0];
        uint256 percentageDenominator = percentageOfFundsForColdStorage[1];
        uint256 amountForColdStorage = orderAmount.mul(percentageNumerator).div(
            percentageDenominator
        );

        token_.transferFrom(whiteListedAddress, address(this), orderAmount);
        token_.transfer(coldStorage, amountForColdStorage);

        return true;
    }
}
