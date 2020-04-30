pragma solidity ^0.5.0;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";


contract KYCVerifier is Ownable {
    address public bridge;

    mapping(address => bool) public whitelistedAddresses;

    function initialize(address ownerAddress) public initializer {
        require(ownerAddress != address(0), "owner adddress must not be empty");
        Ownable.initialize(ownerAddress);
    }

    function isAddressWhitelisted(address userAddress)
        public
        view
        returns (bool)
    {
        return whitelistedAddresses[userAddress];
    }

    // @dev Set whitelisted addresses
    function setWhitelistedAddress(address adddressToAdd)
        public
        onlyOwnerOrBridge
    {
        require(adddressToAdd != address(0), "adddress must not be empty");

        whitelistedAddresses[adddressToAdd] = true;
    }

    // @dev Remove whitelisted addresses
    function removeWhitelistedAddress(address addressToRemove)
        public
        onlyOwnerOrBridge
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

    function setBridge(address _bridge) public onlyOwner {
        require(_bridge != address(0), "adddress must not be empty");
        bridge = _bridge;
    }

    modifier onlyOwnerOrBridge() {
        require(
            isOwner() || _msgSender() == bridge,
            "caller is not the owner or bridge"
        );
        _;
    }
}
