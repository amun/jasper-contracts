pragma solidity ^0.5.0;

import "../CashPool.sol";


// used for Reference only
// with oz sdk one does not actually need to create another smart contract as this and inheret the parent. Add the code directly in the parent smart contract and run `npx upgrade` and choose that contract to upgrade.
contract CashPoolv2 is CashPool {
    mapping(address => bool) public approvedTokenManagers;

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

    modifier onlyOwnerOrTokenSwapv2() {
        require(
            isOwner() || approvedTokenManagers[_msgSender()] == true,
            "caller is not the owner or an approved token swap manager"
        );
        _;
    }

    function moveTokenfromPoolv2(
        address _token,
        address destinationAddress,
        uint256 orderAmount
    ) public onlyOwnerOrTokenSwapv2() returns (bool) {
        InterfaceInverseToken token_ = InterfaceInverseToken(_token);

        token_.transfer(destinationAddress, orderAmount);
        return true;
    }

    function moveTokenToPoolv2(
        address _token,
        address whiteListedAddress,
        uint256 orderAmount
    ) public onlyOwnerOrTokenSwapv2() returns (bool) {
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
