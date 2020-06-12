#!/usr/bin/env bash
mkdir flats
rm -rf flats/*

./node_modules/.bin/truffle-flattener contracts/short-tokens/CompositionCalculator.sol > flats/CompositionCalculator.sol
./node_modules/.bin/truffle-flattener contracts/short-tokens/TokenSwapManager.sol > flats/TokenSwapManager.sol
./node_modules/.bin/truffle-flattener contracts/leverage-tokens/TokenSwapLeverage.sol > flats/TokenSwapLeverage.sol
./node_modules/.bin/truffle-flattener contracts/leverage-tokens/CalculatorLeverage.sol > flats/CalculatorLeverage.sol
./node_modules/.bin/truffle-flattener contracts/leverage-tokens/StorageLeverage.sol > flats/StorageLeverage.sol
./node_modules/.bin/truffle-flattener contracts/short-tokens/PersistentStorage.sol > flats/PersistentStorage.sol
./node_modules/.bin/truffle-flattener contracts/shared/Token/USDC.sol > flats/USDC.sol
./node_modules/.bin/truffle-flattener contracts/shared/Token/USDT.sol > flats/USDT.sol
./node_modules/.bin/truffle-flattener contracts/short-tokens/InverseToken.sol > flats/InverseToken.sol
./node_modules/.bin/truffle-flattener contracts/short-tokens/CashPool.sol > flats/CashPool.sol
./node_modules/.bin/truffle-flattener contracts/short-tokens/KYCVerifier.sol > flats/KYCVerifier.sol
./node_modules/.bin/truffle-flattener contracts/shared/AdminMultiSig/OwnerMultiSig.sol > flats/OwnerMultiSig.sol

