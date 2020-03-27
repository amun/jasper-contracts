#!/usr/bin/env bash

function resetContracts() {
    # Check if ganache is running and terminate if not
    isGanacheRunning="$(pgrep node | xargs ps -fp | grep -c ganache)"
    if [ "$isGanacheRunning" == 1 ]; then
        echo "### Ganache is running. Can move on to compile ###"
    else
        echo "### Ganache isn't running. Please run Ganache (npm run dev) before running this script ###"
        exit
    fi
    if [ "$1" != "" ]; then
        ownerAddress=$1
        coldStorageAddress="0xb07E2E52CfE9119daFf6B419d75f09618b55b824" # account[9] from ganache
        sixtyPercentInFraction=[3,5]
        managementFee=7000000000000000000
        minRebalanceAmount=1000000000000000000
        inverseTokenName='BTCDOWN'
    else
        echo "Please provide to this script the first account on your ganache-cli output"
        exit
    fi

    # deploy all contracts
    echo
    echo "### Compiling and deploying contracts ###"
    rm build/contracts/*.json

    echo
    echo "### Compiling and deploying persistentStorage ###"
    echo
    persistentStorageAddress="$(exec npx oz create PersistentStorage -n development --init --args $ownerAddress,$managementFee,$minRebalanceAmount --no-interactive --force --from $ownerAddress)"


    echo
    echo "### Compiling and deploying KYCVerifier ###"
    echo
    kycVerifierAddress="$(exec npx oz create KYCVerifier -n development --init --args $persistentStorageAddress --no-interactive --force --from $ownerAddress)"

    echo
    echo "### Compiling and deploying CollateralPool ###"
    echo
    collateralPoolAddress="$(exec npx oz create CollateralPool -n development --init --args $ownerAddress,$kycVerifierAddress,$persistentStorageAddress,$coldStorageAddress,$sixtyPercentInFraction --no-interactive --force --from $ownerAddress)"

    echo
    echo "### Compiling and deploying InverseToken ###"
    echo
    inverseTokenAddress="$(exec npx oz create InverseToken -n development --init --args $inverseTokenName,$inverseTokenName,18,$persistentStorageAddress,$ownerAddress --no-interactive --force --from $ownerAddress)"

    echo
    echo "### Compiling and deploying CompositionCalculator ###"
    echo
    compositionCalculatorAddress="$(exec npx oz create CompositionCalculator -n development --init --args $persistentStorageAddress,$inverseTokenAddress --no-interactive --force --from $ownerAddress)"

    echo
    echo "### Compiling and deploying StableCoin (USDC) ###"
    echo
    USDCAddress="$(exec npx oz create USDC -n development --init --args 'USDC','USDC','USD',18,$ownerAddress,$ownerAddress,$ownerAddress,$ownerAddress --no-interactive --force --from $ownerAddress)"

    echo
    echo "### Compiling and deploying TokenSwapManager ###"
    echo
    # TODO: the following bridge is for dev env
    tsmAddress="$(exec npx oz create TokenSwapManager -n development --init --args $ownerAddress,$USDCAddress,$inverseTokenAddress,$persistentStorageAddress,$kycVerifierAddress,$collateralPoolAddress,$compositionCalculatorAddress --no-interactive --force --from $ownerAddress)"

    # echo "PersistentStorage: $persistentStorageAddress"
    # echo "KYCVerifier: $kycVerifierAddress"
    # echo "CollateralPool: $collateralPoolAddress"
    # echo "InverseToken: $inverseTokenAddress"
    # echo "CompositionCalculator: $compositionCalculatorAddress"
    # echo "TokenSwapManager: $tsmAddress"
    # echo "USDCAddress: $USDCAddress"

    printf '{ "KYCVerifier":"%s", "PersistentStorage":"%s", "TokenSwapManager":"%s", "USDC": "%s", "BTCDOWN" : {"InverseToken":"%s", "CollateralPool":"%s", "CompositionCalculator":"%s"} }\n' "$kycVerifierAddress" "$persistentStorageAddress" "$tsmAddress" "$USDCAddress" "$inverseTokenAddress" "$collateralPoolAddress" "$compositionCalculatorAddress" > /tmp/contractsAddresses.json
}

function mintUSDC() {
    # Now invoke the script that mints and transfer 10K USDC to ownerAddress
    echo
    echo "Compiling and deploying finished. Minting USDC"
    echo
    node './scripts/mintUSDC.js'
}

function resetContractsInDB() {
    echo "### Setting contracts data into Jasper DB ###"
    cd ../App/backend && \
    node -r dotenv/config node_modules/.bin/sequelize db:seed --seed 20200308201745-seed-inverse-btc-contracts --config migrations/config.js && \
    cd ../../Contracts
}

# rm .openzeppelin/dev*.json

# Main
resetContracts $1
mintUSDC
if [ -d "../App/backend" ]; then
    resetContractsInDB
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