#!/usr/bin/env bash
mkdir flats
rm -rf flats/*

./node_modules/.bin/truffle-flattener contracts/CompositionCalculator.sol > flats/CompositionCalculator.sol
./node_modules/.bin/truffle-flattener contracts/TokenSwapManager.sol > flats/TokenSwapManager.sol
./node_modules/.bin/truffle-flattener contracts/PersistentStorage.sol > flats/PersistentStorage.sol
./node_modules/.bin/truffle-flattener contracts/Token/USDC.sol > flats/USDC.sol
./node_modules/.bin/truffle-flattener contracts/Token/InverseToken.sol > flats/InverseToken.sol
./node_modules/.bin/truffle-flattener contracts/CashPool.sol > flats/CashPool.sol
./node_modules/.bin/truffle-flattener contracts/KYCVerifier.sol > flats/KYCVerifier.sol

