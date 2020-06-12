pragma solidity ^0.5.0;


interface InterfaceCompositionCalculator {
    function getCurrentCashAmountCreatedByToken(
        uint256 _tokenAmount,
        uint256 _spotPrice,
        uint256 _gasFee
    ) external view returns (uint256);

    function getCurrentTokenAmountCreatedByCash(
        uint256 _cash,
        uint256 _spotPrice,
        uint256 _gasFee
    ) external view returns (uint256);

    function calculateDailyPCF(uint256 _price, uint256 _lendingFee)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, bool);
}
