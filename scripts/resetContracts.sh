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
    persistentStorageAddress="$(exec npx oz create PersistentStorage -n development --init --args $ownerAddress --no-interactive --force --from $ownerAddress)"

    echo
    echo "### Compiling and deploying KYCVerifier ###"
    echo
    kycVerifierAddress="$(exec npx oz create KYCVerifier -n development --init --args $persistentStorageAddress --no-interactive --force --from $ownerAddress)"

    echo
    echo "### Compiling and deploying CollateralPool ###"
    echo
    collateralPoolAddress="$(exec npx oz create CollateralPool -n development --init --args $ownerAddress,$kycVerifierAddress --no-interactive --force --from $ownerAddress)"

    echo
    echo "### Compiling and deploying InverseToken ###"
    echo
    inverseTokenAddress="$(exec npx oz create InverseToken -n development --init --args 'BTCDOWN','BTCDOWN',18 --no-interactive --force --from $ownerAddress)"

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
    bridgeAddress='0x5E85aC4bCe64892DDF52D4375BA65B0536e75D44'
    tsmAddress="$(exec npx oz create TokenSwapManager -n development --init --args $bridgeAddress,$USDCAddress,$inverseTokenAddress,$persistentStorageAddress,$kycVerifierAddress,$collateralPoolAddress,$compositionCalculatorAddress --no-interactive --force --from $ownerAddress)"

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
    node '../App/backend/scripts/mintUSDC.js'
}

function resetContractsInDB() {
    echo "### Setting contracts data into Jasper DB ###"
    cd ../App/backend && \
    node -r dotenv/config node_modules/.bin/sequelize db:seed --seed 20200308201745-seed-inverse-btc-contracts --config migrations/config.js && \
    cd ../../Contracts
}


# Main
resetContracts $1
mintUSDC
resetContractsInDB


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