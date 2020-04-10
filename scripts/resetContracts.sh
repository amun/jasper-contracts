#!/usr/bin/env bash

function resetContracts() {

    rm build/contracts/*.json

    # Check if ganache is running and terminate if not
    isGanacheRunning="$(pgrep node | xargs ps -fp | grep -c ganache)"

    if [ "$isGanacheRunning" == 1 ]; then
        echo "### Ganache is running. Can move on to compile ###"
    else
        echo "### Ganache isn't running. Please run Ganache (npm run dev) before running this script ###"
        exit
    fi

    coldStorageAddress="0xb07E2E52CfE9119daFf6B419d75f09618b55b824" # account[9] from ganache
    zeroPercentInFraction=[0,1]
    managementFee=7000000000000000000
    minRebalanceAmount=1000000000000000000
    inverseTokenName='BTCDOWN'

    if [ "$1" != "" ]; then
        echo "Deploying contracts with simple owner (contracts only mode)"
        isDappMode=false
        ownerAddress=$1
    else
        echo "Deploying contracts through Multisig owner (full dapp mode)"
        isDappMode=true
        signers="[0x9e74E6Be10B63A7442184dFFD633fbed80175B34,0x5E85aC4bCe64892DDF52D4375BA65B0536e75D44,0xa60b7DAd9E1A4a563fE87c48c76c427E4dEb29A5]"
        requiredSignature=1 # in development, 2 is required in staging and production
        ownerAddress=$(exec npx oz create OwnerMultiSig -n development --init --args $signers,$requiredSignature --no-interactive --force 2>&1 | grep -oe '0x.*$' | tail -1)
    fi

    # deploy all contracts
    echo
    echo "### Compiling and deploying contracts ###"

    echo
    echo "### Compiling and deploying persistentStorage ###"
    echo
    persistentStorageAddress="$(exec npx oz create PersistentStorage -n development --init --args $ownerAddress,$managementFee,$minRebalanceAmount --no-interactive --force)"


    echo
    echo "### Compiling and deploying KYCVerifier ###"
    echo
    kycVerifierAddress="$(exec npx oz create KYCVerifier -n development --init --args $persistentStorageAddress --no-interactive --force)"

    echo
    echo "### Compiling and deploying CashPool ###"
    echo
    cashPoolAddress="$(exec npx oz create CashPool -n development --init --args $ownerAddress,$kycVerifierAddress,$persistentStorageAddress,$coldStorageAddress,$zeroPercentInFraction --no-interactive --force)"

    echo
    echo "### Compiling and deploying InverseToken ###"
    echo
    inverseTokenAddress="$(exec npx oz create InverseToken -n development --init --args $inverseTokenName,$inverseTokenName,18,$persistentStorageAddress,$ownerAddress --no-interactive --force)"

    echo
    echo "### Compiling and deploying CompositionCalculator ###"
    echo
    compositionCalculatorAddress="$(exec npx oz create CompositionCalculator -n development --init --args $persistentStorageAddress,$inverseTokenAddress --no-interactive --force)"

    echo
    echo "### Compiling and deploying StableCoin (USDC) ###"
    echo
    USDCAddress="$(exec npx oz create USDC -n development --init --args 'USDC','USDC','USD',6,$ownerAddress,$ownerAddress,$ownerAddress,$ownerAddress --no-interactive --force)"

    echo
    echo "### Compiling and deploying TokenSwapManager ###"
    echo
    tsmAddress="$(exec npx oz create TokenSwapManager -n development --init --args $ownerAddress,$USDCAddress,$inverseTokenAddress,$cashPoolAddress,$compositionCalculatorAddress --no-interactive --force)"

    # echo "KYCVerifier: $kycVerifierAddress"
    # echo "PersistentStorage: $persistentStorageAddress"
    # echo "TokenSwapManager: $tsmAddress"
    # echo "USDCAddress: $USDCAddress"
    # echo "InverseToken: $inverseTokenAddress"
    # echo "CashPool: $cashPoolAddress"
    # echo "CompositionCalculator: $compositionCalculatorAddress"

    printf '{ "KYCVerifier":"%s", "PersistentStorage":"%s", "TokenSwapManager":"%s", "USDC": "%s", "InverseToken":"%s", "CashPool":"%s", "CompositionCalculator":"%s", "OwnerMultiSig":"%s" }\n' "$kycVerifierAddress" "$persistentStorageAddress" "$tsmAddress" "$USDCAddress" "$inverseTokenAddress" "$cashPoolAddress" "$compositionCalculatorAddress" "$ownerAddress" > /tmp/contractsAddresses.json



}

function flattenContracts() {
    echo
    echo "### Flatten contracts into /flat ###"
    echo

    npm run flatten
}


function mintUSDC() {
    # Now invoke the script that mints and transfer 10K USDC to ownerAddress
    echo
    echo "Minting USDC"
    echo
    node './scripts/mintUSDC.js' $isDappMode
}

function mintInverseTokens() {
    # Now invoke the script that whitelists ownerAddress
    echo
    echo "Mint initial inverse Tokens, KYC whitelist ownerAddress and set Token SwapManager Address in PersistentStorage"
    echo
    node './scripts/mintInverseTokens.js' $isDappMode
}

function contractsInit() {
    # Now invoke the script that sets up CompositionCalculation, persitentStorage and InverseToken contracts
    echo
    echo "grooming CompositionCalculation, persitentStorage and InverseToken contracts"
    echo
    node './scripts/contractsInit.js'
}

function resetContractsInDB() {
    echo "### Setting contracts data into Jasper DB ###"
    cd ../App/backend && \
    # node -r dotenv/config node_modules/.bin/sequelize db:seed --seed 20200308201745-seed-inverse-btc-contracts --config migrations/config.js && \
    exec npm run db:reset
    # node -r dotenv/config node_modules/.bin/sequelize db:seed --seed 20200308201745-seed-inverse-btc-contracts --config migrations/config.js && \

    cd ../../Contracts
}

function createLendingRates() {
    echo "### Trying to set Lending Rates for 30 days at 2% from Blockfi ###"
    echo "### Make sure your backend is running  ###"
    node '../App/backend/scripts/createLendingRates.js'
    echo "done"
}

# Main
resetContracts $1
flattenContracts
mintInverseTokens
mintUSDC
if [ -d "../App/backend" ]; then
    resetContractsInDB
    createLendingRates
else
    echo "Your setup seems to be missing the backend of Jasper. Not seeding DB data"
fi


# try (hack)
# (
#   # this flag will make to exit from current subshell on any error
#   # inside it (all functions run inside will also break on any error)
#   set -e
#   resetContracts $1
#   mintUSDC
# #   resetContractsInDB
# )
# # catch (hack)
# errorCode=$?
# if [ $errorCode -ne 0 ]; then
#   echo "It seems that the DB seeder already ran..."
#   echo "If you wish to rerun the contracts seeder in the db, run the following in your DB:"
#   echo "DELETE * FROM \"SequelizeData\" WHERE \"name\" = '20200308201745-seed-inverse-btc-contracts.js'"
#   echo "And then either run this script again, or just the \"resetContractsInDB\" function content"
#   # exit $errorCode
# fi