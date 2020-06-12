pragma solidity ^0.5.0;


interface InterfaceCashPool {
    function kycVerifier() external view returns (address);

    function moveTokenToPool(
        address _token,
        address whiteListedAddress,
        uint256 orderAmount
    ) external returns (bool);

    function moveTokenfromPool(
        address _token,
        address destinationAddress,
        uint256 orderAmount
    ) external returns (bool);
}
