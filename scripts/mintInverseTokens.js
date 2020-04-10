const fs = require('fs');
const path = require('path');
const Web3 = require('web3');
const web3 = new Web3('http://127.0.0.1:8545');
const BigNumber = require('bignumber.js');

const bridgeAddress =
  process.env.BRIDGE_ADDRESS || '0x9e74E6Be10B63A7442184dFFD633fbed80175B34';

const abisDir = path.join(
  __dirname,
  '..',
  'build',
  'contracts'
);

let contractsAddresses = fs.readFileSync('/tmp/contractsAddresses.json');
contractsAddresses = JSON.parse(contractsAddresses);
if (!Object.values(contractsAddresses).every((val) => val)) {
  throw new Error(
    "Some of the contract deployments didn't work well. Try rerun the contracts reset script"
  );
}

const getContract = (contractName) => {
  const contractAddress = contractsAddresses[contractName];

  const jsonPath = path.join(abisDir, `${contractName}.json`);
  let contractContent = fs.readFileSync(jsonPath);
  contractContent = JSON.parse(contractContent);
  const contractAbi = contractContent.abi;
  const instantiatedContract = new web3.eth.Contract(
    contractAbi,
    contractAddress
  );
  return instantiatedContract;
};

const getContractAbi = (contractName) => {
  const contractAddress = contractsAddresses[contractName];

  const jsonPath = path.join(abisDir, `${contractName}.json`);
  let contractContent = fs.readFileSync(jsonPath);
  contractContent = JSON.parse(contractContent);
  const contractAbi = contractContent.abi;

  return contractAbi;
};

const sendTransaction = async (method) => {
  const gasEstimate = await method.estimateGas({ from: bridgeAddress });
  return method.send({
    from: bridgeAddress,
    gas: gasEstimate,
    gasPrice: 10,
  });
};

function encodeFunction(abiArray, functionName, functionArgs) {
  for (const object of abiArray)
    if (object.name == functionName)
      return web3.eth.abi.encodeFunctionCall(object, functionArgs);
  throw new Error('function ' + functionName + ' does not exist');
}

(async () => {
  const isDappMode = process.argv.length > 2 && process.argv[2] === 'true';
  const accounts = await web3.eth.getAccounts();
  const mainAccount = accounts[0];
  const persistentStorageContract = getContract('PersistentStorage');
  const inverseTokenContract = getContract('InverseToken');
  const compositionCalculatorContract = getContract('CompositionCalculator');

  if (isDappMode) {
    const multiSigContract = getContract('OwnerMultiSig');
    const ownerMultiSigAddress = multiSigContract.options.address;

    // setBridge
    const encodedSetBridge = encodeFunction(
      getContractAbi('PersistentStorage'),
      'setBridge',
      [bridgeAddress]
    );
    await multiSigContract.methods
      .submitTransaction(
        persistentStorageContract.options.address,
        0,
        encodedSetBridge
      )
      .send({ from: mainAccount, gasPrice: 1, gas: 1212720 });

    // whitelist mainAccount via the admin multisig
    const encodedWhitelister = encodeFunction(
      getContractAbi('PersistentStorage'),
      'setWhitelistedAddress',
      [mainAccount]
    );
    await multiSigContract.methods
      .submitTransaction(
        persistentStorageContract.options.address,
        0,
        encodedWhitelister
      )
      .send({ from: mainAccount, gasPrice: 1, gas: 1212720 });

    // set tokenSwapManager
    const encodedTsmCall = encodeFunction(
      getContractAbi('PersistentStorage'),
      'setTokenSwapManager',
      [contractsAddresses['TokenSwapManager']]
    );
    await multiSigContract.methods
      .submitTransaction(
        persistentStorageContract.options.address,
        0,
        encodedTsmCall
      )
      .send({ from: mainAccount, gasPrice: 1, gas: 1212720 });

    // mint tokens
    const lendingFee = '2.5';
    const balance = '200'; //# of crypto balance
    const oldCashPosition = '2000000';
    const price = '7000';
    const minRebalanceAmount = '1';
    const totalTokenSupply = '10000';

    let totalSupply = await inverseTokenContract.methods.totalSupply().call();
    totalSupply = web3.utils.fromWei(totalSupply);

    const toMint = new BigNumber(totalTokenSupply)
      .minus(totalSupply)
      .toString();

    const encodedMintCall = encodeFunction(
      getContractAbi('InverseToken'),
      'mintTokens',
      [bridgeAddress, web3.utils.toWei(toMint)]
    );
    let mintResult = await multiSigContract.methods
      .submitTransaction(
        inverseTokenContract.options.address,
        0,
        encodedMintCall
      )
      .send({ from: mainAccount, gasPrice: 1, gas: 1212720 });

    // Set accounting
    totalSupply = await inverseTokenContract.methods.totalSupply().call();
    totalSupply = web3.utils.fromWei(totalSupply);

    const cashPositionPerTokenUnit = new BigNumber(oldCashPosition)
      .dividedBy(totalSupply)
      .toString();
    const balancePerTokenUnit = new BigNumber(balance)
      .dividedBy(totalSupply)
      .toString();

    const encodedAccountingCall = encodeFunction(
      getContractAbi('PersistentStorage'),
      'setAccounting',
      [
        web3.utils.toWei(price),
        web3.utils.toWei(cashPositionPerTokenUnit),
        web3.utils.toWei(balancePerTokenUnit),
        web3.utils.toWei(lendingFee),
      ]
    );

    await multiSigContract.methods
      .submitTransaction(
        persistentStorageContract.options.address,
        0,
        encodedAccountingCall
      )
      .send({ from: mainAccount, gasPrice: 1, gas: 1212720 });

    // setMinRebalanceAmount
    const encodedMinRebalanceAmountCall = encodeFunction(
      getContractAbi('PersistentStorage'),
      'setMinRebalanceAmount',
      [web3.utils.toWei(minRebalanceAmount)]
    );

    await multiSigContract.methods
      .submitTransaction(
        persistentStorageContract.options.address,
        0,
        encodedMinRebalanceAmountCall
      )
      .send({ from: mainAccount, gasPrice: 1, gas: 1212720 });

    const balancePerTokenUnitContract = await persistentStorageContract.methods
      .getBalancePerTokenUnit()
      .call();
    const cashPositionPerTokenUnitContract = await persistentStorageContract.methods
      .getCashPositionPerTokenUnit()
      .call();

    const totalBalance = await compositionCalculatorContract.methods
      .getTotalBalance()
      .call();
    const totalCashPosition = await compositionCalculatorContract.methods
      .getTotalCashPosition()
      .call();

    // Leaving commented out for debugging purposes
    // console.log({
    //   totalTokenSupply,
    //   totalSupply,
    //   cashPositionPerTokenUnit,
    //   balancePerToken,
    //   balancePerTokenContract,
    //   cashPositionPerTokenContract,
    //   totalBalance,
    //   totalCashPosition,
    // });

    const mainAccountBalance = await inverseTokenContract.methods
      .balanceOf(mainAccount)
      .call();

    console.log('Finieshed minting BTCDOWN');
    console.log(
      'mainAccountBalance: ',
      web3.utils.fromWei(mainAccountBalance),
      'BTCDOWN'
    );
  } else {
    // contracts only mode

    // whitelist mainAccount
    await persistentStorageContract.methods
      .setWhitelistedAddress(mainAccount)
      .send({ from: mainAccount, gasPrice: 1, gas: 121272 });

    // set tokenSwapManager
    await persistentStorageContract.methods
      .setTokenSwapManager(contractsAddresses['TokenSwapManager'])
      .send({ from: mainAccount, gasPrice: 1, gas: 121272 });

    // mint tokens
    const lendingFee = '2.5';
    const balance = '200'; //# of crypto balance
    const oldCashPosition = '2000000';
    const price = '7000';
    const minRebalanceAmount = '1';
    const totalTokenSupply = '10000';

    let totalSupply = await inverseTokenContract.methods.totalSupply().call();
    totalSupply = web3.utils.fromWei(totalSupply);

    const toMint = new BigNumber(totalTokenSupply)
      .minus(totalSupply)
      .toString();

    let mintResult = await inverseTokenContract.methods
      .mintTokens(bridgeAddress, web3.utils.toWei(toMint))
      .send({ from: bridgeAddress });

    totalSupply = await inverseTokenContract.methods.totalSupply().call();
    totalSupply = web3.utils.fromWei(totalSupply);

    const cashPositionPerTokenUnit = new BigNumber(oldCashPosition)
      .dividedBy(totalSupply)
      .toString();
    const balancePerToken = new BigNumber(balance)
      .dividedBy(totalSupply)
      .toString();

    await sendTransaction(
      persistentStorageContract.methods.setAccounting(
        web3.utils.toWei(price),
        web3.utils.toWei(cashPositionPerTokenUnit),
        web3.utils.toWei(balancePerToken),
        web3.utils.toWei(lendingFee)
      )
    );
    await persistentStorageContract.methods
      .setMinRebalanceAmount(web3.utils.toWei(minRebalanceAmount))
      .send({ from: bridgeAddress });

    await persistentStorageContract.methods
      .setTokenSwapManager(contractsAddresses['TokenSwapManager'])
      .send({ from: bridgeAddress });

    const balancePerTokenContract = await persistentStorageContract.methods
      .getBalancePerTokenUnit()
      .call();
    const cashPositionPerTokenContract = await persistentStorageContract.methods
      .getCashPositionPerTokenUnit()
      .call();

    const totalBalance = await compositionCalculatorContract.methods
      .getTotalBalance()
      .call();
    const totalCashPosition = await compositionCalculatorContract.methods
      .getTotalCashPosition()
      .call();

    // Leaving commented out for debugging purposes
    // console.log({
    //   totalTokenSupply,
    //   totalSupply,
    //   cashPositionPerTokenUnit,
    //   balancePerToken,
    //   balancePerTokenContract,
    //   cashPositionPerTokenContract,
    //   totalBalance,
    //   totalCashPosition,
    // });

    const mainAccountBalance = await inverseTokenContract.methods
      .balanceOf(mainAccount)
      .call();

    console.log('Finieshed minting BTCDOWN');
    console.log(
      'mainAccountBalance: ',
      web3.utils.fromWei(mainAccountBalance),
      'BTCDOWN'
    );
  }
})();
