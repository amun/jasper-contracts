pragma solidity ^0.5.0;


interface InterfaceStorage {
    function whitelistedAddresses(address) external view returns (bool);

    function isPaused() external view returns (bool);

    function isShutdown() external view returns (bool);

    function tokenSwapManager() external view returns (address);

    function bridge() external view returns (address);

    function getCashPositionPerTokenUnit() external view returns (uint256);

    function getBalancePerTokenUnit() external view returns (uint256);

    function getMintingFee(uint256 cash) external view returns (uint256);

    function getPrice() external view returns (uint256);

    function minimumMintingFee() external view returns (uint256);

    function getLendingFee() external view returns (uint256);

    function minRebalanceAmount() external view returns (uint8);

    function delayedRedemptionsByUser(address) external view returns (uint256);

    function setDelayedRedemptionsByUser(
        uint256 amountToRedeem,
        address whitelistedAddress
    ) external;

    function setOrderByUser(
        address whitelistedAddress,
        string calldata orderType,
        uint256 tokensGiven,
        uint256 tokensRecieved,
        uint256 avgBlendedFee,
        uint256 orderIndex,
        bool overwrite
    ) external;

    function setAccounting(
        uint256 _price,
        uint256 _cashPositionPerTokenUnit,
        uint256 _balancePerTokenUnit,
        uint256 _lendingFee
    ) external;

    function setAccountingForLastActivityDay(
        uint256 _price,
        uint256 _cashPositionPerTokenUnit,
        uint256 _balancePerTokenUnit,
        uint256 _lendingFee
    ) external;
}
