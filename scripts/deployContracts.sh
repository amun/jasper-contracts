#!/usr/bin/env bash

function deployContracts() {

    if [ "$network" == "development" ]; then
        # Check if ganache is running and terminate if not
        isGanacheRunning="$(pgrep node | xargs ps -fp | grep -c ganache)"

        if [ "$isGanacheRunning" == 1 ]; then
            echo "### Ganache is running. Can move on to compile ###"
        else
            echo "### Ganache isn't running. Please run Ganache (npm run dev) before running this script ###"
            exit
        fi
    else
        echo "### Deploying contract on ${network} network ###"
    fi

    managementFee=11000000000000000000
    minRebalanceAmount=1000000000000000000
    inverseTokenName=$2
    lastMintingFee=1000000000000000;
    balancePrecision=12;
    minimumMintingFee=0; # $5
    minimumTrade=50000000000000000000;  # $50


    if [ "$isLeverageToken" == "true" ]; then
        echo
        echo "### Deploying StorageLeverage ###"
        echo
        persistenStorageContractName="StorageLeverage"
        persistentStorageAddress="$(exec npx oz create StorageLeverage -n ${network} --init --args $ownerAddress,$managementFee,$minRebalanceAmount,$balancePrecision,$lastMintingFee,$minimumMintingFee,$minimumTrade --no-interactive --force)"
    else
        echo
        echo "### Compiling and deploying persistentStorage ###"
        echo
        persistenStorageContractName="PersistentStorage"
        persistentStorageAddress="$(exec npx oz create PersistentStorage -n ${network} --init --args $ownerAddress,$managementFee,$minRebalanceAmount,$balancePrecision,$lastMintingFee,$minimumMintingFee,$minimumTrade --no-interactive --force)"
    fi

    echo
    echo "### Compiling and deploying InverseToken ###"
    echo
    inverseTokenAddress="$(exec npx oz create InverseToken -n ${network} --init --args $inverseTokenName,$inverseTokenName,18,$persistentStorageAddress,$ownerAddress --no-interactive --force)"


    if [ "$isLeverageToken" == "true" ]; then
        echo
        echo "### Deploying CalculatorLeverage ###"
        echo
        compositionCalculatorContractName="CalculatorLeverage"
        compositionCalculatorAddress="$(exec npx oz create CalculatorLeverage -n ${network} --init --args $persistentStorageAddress,$inverseTokenAddress --no-interactive --force)"
    else
        echo
        echo "### Compiling and deploying CompositionCalculator ###"
        echo
        compositionCalculatorContractName="CompositionCalculator"
        compositionCalculatorAddress="$(exec npx oz create CompositionCalculator -n ${network} --init --args $persistentStorageAddress,$inverseTokenAddress --no-interactive --force)"
    fi


    if [ "$isLeverageToken" == "true" ]; then
        echo
        echo "### Deploying TokenSwapLeverage ###"
        echo
        tsmContractName="TokenSwapLeverage"
        tsmAddress="$(exec npx oz create TokenSwapLeverage -n ${network} --init --args $ownerAddress,$inverseTokenAddress,$cashPoolAddress,$persistentStorageAddress,$compositionCalculatorAddress --no-interactive --force)"
    else
        echo
        echo "### Compiling and deploying TokenSwapManager ###"
        echo
        tsmContractName="TokenSwapManager"
        tsmAddress="$(exec npx oz create TokenSwapManager -n ${network} --init --args $ownerAddress,$inverseTokenAddress,$cashPoolAddress,$persistentStorageAddress,$compositionCalculatorAddress --no-interactive --force)"
    fi

    if [ "$isLeverageToken" == "true" ]; then
        echo
        echo "### Deploying TokenSwapLeverage ###"
        echo
        stablecoinContractName="USDT"
        stablecoinContractAddress=${USDTAddress}
    else
        echo
        echo "### Compiling and deploying TokenSwapManager ###"
        echo
        stablecoinContractName="USDC"
        stablecoinContractAddress=${USDCAddress}

    fi


    json='{"KYCVerifier":"'${kycVerifierAddress}'","'${persistenStorageContractName}'":"'${persistentStorageAddress}'","'${tsmContractName}'":"'${tsmAddress}'","'${stablecoinContractName}'":"'${stablecoinContractAddress}'","InverseToken":"'${inverseTokenAddress}'","CashPool":"'${cashPoolAddress}'","'${compositionCalculatorContractName}'":"'${compositionCalculatorAddress}'","OwnerMultiSig":"'${ownerAddress}'","ColdStorageMultiSig":"'${coldStorageAddress}'"}'

    if [ "$network" == "mainnet" ]; then
        echo
        echo "Saving contract addresses to S3 for ${network}"
        node '../App/backend/scripts/addContractAddressesToS3.js' ${inverseTokenName}contractsAddresses $json $network
        echo
    elif [ "$network" == "rinkeby" ]; then
        echo
        echo "Saving contract addresses to S3 for ${network}"
        node '../App/backend/scripts/addContractAddressesToS3.js' ${inverseTokenName}contractsAddresses $json $network
        echo
    else
        echo
        echo "### Saving contracts file locally for ${network} network ###"
        printf $json > /tmp/${inverseTokenName}contractsAddresses.json
        echo
    fi
}

function setIsDappMode() {
        printf '{ "isDappMode":"%s" }\n' "$isDappMode" > /tmp/isDappMode.json
}

function flattenContracts() {
    echo
    echo "### Flatten contracts into /flat ###"
    echo

    npm run flatten
}

function setUpContractsWithMintInverseTokens() {
    product=$1
    network=$2
    isLeverageToken=$3
    # Now invoke the script that whitelists ownerAddress
    echo
    echo "Mint initial inverse Tokens, set bridgeAddress on KycVerifier contract,  KYC whitelist ownerAddress and set Token SwapManager Address in PersistentStorage"
    echo
    node '../App/backend/scripts/setUpContractsWithMintInverseTokens.js' $product $network $isLeverageToken
}

function resetContractsInDB() {
    echo "### Setting contracts data into Jasper DB ###"
    cd ../App/backend && \
    exec npm run db:reset

    cd ../../Contracts
}

function createLendingRates() {
    echo "### Trying to set Lending Rates for 30 days at 2% from Blockfi ###"
    echo "### Make sure your backend is running  ###"
    echo "### ONLY CREATING FOR BTCSHORT  ###"

    exec npm run script:createLendingRates
    echo "done"
}

function createFirstRebalanceInDBForInverseNonLeveraged() {
    echo "### Trying to set Setup Contracts in DB with initial minted token and price ###"
    echo "### Make sure your backend is running  ###"
    echo "### ONLY CREATING FOR BTCSHORT  ###"
    exec npm run script:createFirstRebalanceInDBForInverseNonLeveraged
    echo "done"
}

# Main
network=$1
products=$2  # "BTC2L BTCSHORT", space separated string or "all" for all contracts


rm build/contracts/*.json

npx oz push -n $network
 # deploy all contracts
echo
echo "### Compiling and deploying contracts ###"

if [ "$network" == "mainnet" ]; then
    echo
    ownerAddress="0x786ea62bC54613C3639A6275f88D3b86Ce3a0D45"
    echo "OwnerMultisig for ${network} network is ${ownerAddress}"
    echo
    coldStorageAddress="0x555EAc576C533579834aE1a6AF6FC1d1925E7D71"
    echo "ColdStorageMultisig for ${network} network is ${coldStorageAddress}"
    echo
    # source: https://etherscan.io/token/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
    USDCAddress="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    echo "USDC for ${network} network is ${USDCAddress}"
    echo
    # source: https://etherscan.io/token/0xdac17f958d2ee523a2206206994597c13d831ec7
    USDTAddress="0xdac17f958d2ee523a2206206994597c13d831ec7"
    echo "USDC for ${network} network is ${USDCAddress}"
    echo
    kycVerifierAddress="0xE2E2fB43412818f9827B9e0943C031a518Ef451c"
    echo "KycVerifier for ${network} network is ${kycVerifierAddress}"
    echo
    cashPoolAddress="0x98EABA2684b49BbDe9842cd48f3bAE8cAA31dac4"
    echo "CashPool for ${network} network is ${cashPoolAddress}"
elif [ "$network" == "rinkeby" ]; then
    echo
    ownerAddress="0xa86223E26a74Eb292f23793BE18a3D1A3d5E1495"
    echo "OwnerMultisig for ${network} network is ${ownerAddress}"
    echo
    coldStorageAddress="0x296DFFEf40DfE7b6C356419aF879eB5Cb3fd64E6"
    echo "ColdStorageMultisig for ${network} network is ${coldStorageAddress}"
    echo
    USDCAddress="0x3033f7d702C602BaF4b2D340B8A3DD29f3d91DEf"
    echo "USDC for ${network} network is ${USDCAddress}"
    echo
    USDTAddress="0x8175a4d188cF8317CC1Bf3505C2f709764076987"
    echo "USDT for ${network} network is ${USDTAddress}"
    echo
    kycVerifierAddress="0x3B1110fc383ADC316133bc16fDb2137731ef5B88"
    echo "KycVerifier for ${network} network is ${kycVerifierAddress}"
    echo
    cashPoolAddress="0xDDeF3814b8D6907f61C90A5cC90F38e33fC7Dc36"
    echo "CashPool for ${network} network is ${cashPoolAddress}"
else
    if [ "$network" != 'development' ]; then
        echo
        echo "Missing network. Must be development, rinkeby or mainnet  "
        exit
    fi
    echo
    echo "Deploying contracts through Multisig owner (full dapp mode)"
    isDappMode=true
    signers="[0x2a78B494852fc74c25B70eC69a78D7332c7Dc87d,0x7e56019B6c9FDA6eE3B98B860E51195d42861355,0xC3902c4e6cbD0AaB4E88bdDBAD75Ac13c9287ABf]"
    requiredSignature=2
    ownerAddress="$(exec npx oz create OwnerMultiSig -n ${network} --init --args $signers,$requiredSignature --no-interactive --force)"
    coldStorageAddress="$(exec npx oz create OwnerMultiSig -n ${network} --init --args $signers,$requiredSignature --no-interactive --force)"
    echo "Deployed ownerMultisig at ${ownerAddress} and coldStorage at ${coldStorageAddress}s"
    echo
    echo "### Compiling and deploying StableCoin (USDC) in ${network} network ###"
    echo
    USDCAddress="$(exec npx oz create USDC -n ${network} --init --args 'USDC','USDC','USD',6,$ownerAddress,$ownerAddress,$ownerAddress,$ownerAddress --no-interactive --force)"
    echo
    echo "### Deployed StableCoin (USDC) at ${USDCAddress} ###"
    echo

    echo "### Compiling and deploying Tether USD (USDT) in ${network} network ###"
    echo
    USDTAddress="$(exec npx oz create USDT -n ${network} --init --args 'USDT','USDT','USD',6,$ownerAddress,$ownerAddress,$ownerAddress,$ownerAddress --no-interactive --force)"
    echo
    echo "### Deployed Tether USD (USDT) at ${USDTAddress} ###"
    echo

    echo "### Compiling and deploying KYCVerifier ###"
    echo
    kycVerifierAddress="$(exec npx oz create KYCVerifier -n ${network} --init --args $ownerAddress --no-interactive --force)"

    echo
    echo "### Compiling and deploying CashPool ###"
    echo
    zeroPercentInFraction=[0,1]
    cashPoolAddress="$(exec npx oz create CashPool -n ${network} --init --args $ownerAddress,$kycVerifierAddress,$coldStorageAddress,$zeroPercentInFraction --no-interactive --force)"
fi


if [ "${products}" == "all" ]; then
    echo "Inside products all"
    products="BTCSHORT ETHSHORT BCHSHORT BTC2S BTC2L BTC3S BTC3L ETH2S ETH2L ETH3S ETH3L"
fi

echo "Products ${products}"

for product in $products
do
    echo
    echo
    if [[ "BTC2S BTC2L BTC3S BTC3L ETH2S ETH2L ETH3S ETH3L" =~ $product ]]; then
        isLeverageToken="true"
        echo "Starting deployment for ${product} in ${network} network; IsLeverageToken: true"
    else
        isLeverageToken=""
        echo "Starting deployment for ${product} in ${network} network; Product ${product}; IsLeverageToken: false"
    fi

    deployContracts $network $product $isLeverageToken
    setIsDappMode
    flattenContracts
    setUpContractsWithMintInverseTokens $product $network $isLeverageToken
done


if [ "$network" == "mainnet" ]; then
    echo
    echo "### Saving contract ABIs to S3 for ${network} ###"
    node '../App/backend/scripts/addContractsAbiToS3.js' $network
    echo
elif [ "$network" == "rinkeby" ]; then
    echo
    echo "### Saving contract ABIs to S3 for ${network} ###"
    node '../App/backend/scripts/addContractsAbiToS3.js' $network
    echo
fi

if [ "$network" == "development" ]; then
    if [ -d "../App/backend" ]; then
        resetContractsInDB
        createLendingRates
        createFirstRebalanceInDBForInverseNonLeveraged
    else
        echo "Your setup seems to be missing the backend of Jasper. Not seeding DB data"
    fi
else
    echo "Not running db reset because it is in ${network} network. It is only used for development network"
fi
