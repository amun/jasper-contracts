const fs = require("fs");
const path = require("path");
const Web3 = require("web3");
const web3 = new Web3("http://127.0.0.1:8545");
const BigNumber = require("bignumber.js");

const bridgeAddress =
  process.env.BRIDGE_ADDRESS || "0x9e74E6Be10B63A7442184dFFD633fbed80175B34";

const abisDir = path.join(__dirname, "../", "build", "contracts");

let contractsAddresses = fs.readFileSync("/tmp/contractsAddresses.json");
contractsAddresses = JSON.parse(contractsAddresses);
if (!Object.values(contractsAddresses).every(val => val)) {
  throw new Error(
    "Some of the contract deployments didn't work well. Try rerun the contracts reset script"
  );
}

const getContract = contractName => {
  const contractAddress =
    contractsAddresses[contractName] ||
    contractsAddresses["BTCDOWN"][contractName];

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

const sendTransaction = async method => {
  const gasEstimate = await method.estimateGas({ from: bridgeAddress });
  return method.send({
    from: bridgeAddress,
    gas: gasEstimate,
    gasPrice: 10
  });
};

(async () => {
  const accounts = await web3.eth.getAccounts();
  const ownerAddress = accounts[0];

  const persistentStorageContract = getContract("PersistentStorage");
  const inverseTokenContract = getContract("InverseToken");
  const compositionCalculatorContract = getContract("CompositionCalculator");

  // whitelist ownerAddress
  await persistentStorageContract.methods
    .setWhitelistedAddress(ownerAddress)
    .send({ from: ownerAddress, gasPrice: 1, gas: 121272 });

  console.log(`Owner Address ${ownerAddress} has been whitelisted `);

  // set tokenSwapManager to ownerAddress
  await persistentStorageContract.methods
    .setTokenSwapManager(contractsAddresses["TokenSwapManager"])
    .send({ from: ownerAddress, gasPrice: 1, gas: 121272 });

  console.log(
    `TokenSwap Manager Contract Address is set on Persistent Storage with address ${contractsAddresses["TokenSwapManager"]}`
  );

  // mint/burn tokens
  const lendingFee = "2.5";
  const balance = "100";
  const oldCashPosition = "200000";
  const price = "1300";
  const minRebalanceAmount = "1";
  const totalTokenSupply = "2";

  let totalSupply = await inverseTokenContract.methods.totalSupply().call();
  totalSupply = web3.utils.fromWei(totalSupply);

  const toMint = new BigNumber(totalTokenSupply).minus(totalSupply).toString();

  console.log({ toMint });
  let mintResult = await inverseTokenContract.methods
    .mintTokens(bridgeAddress, web3.utils.toWei(toMint))
    .send({ from: bridgeAddress });

  console.log({ mintResult: mintResult.transactionHash });

  totalSupply = await inverseTokenContract.methods.totalSupply().call();
  totalSupply = web3.utils.fromWei(totalSupply);

  const cashPositionPerTokenUnit = new BigNumber(oldCashPosition)
    .dividedBy(totalSupply)
    .toString();
  const balancePerTokenUnit = new BigNumber(balance)
    .dividedBy(totalSupply)
    .toString();

  await sendTransaction(
    persistentStorageContract.methods.setAccounting(
      web3.utils.toWei(price),
      web3.utils.toWei(cashPositionPerTokenUnit),
      web3.utils.toWei(balancePerTokenUnit),
      web3.utils.toWei(lendingFee)
    )
  );
  await persistentStorageContract.methods
    .setMinRebalanceAmount(web3.utils.toWei(minRebalanceAmount))
    .send({ from: bridgeAddress });

  await persistentStorageContract.methods
    .setTokenSwapManager(contractsAddresses["TokenSwapManager"])
    .send({ from: bridgeAddress });

  console.log({
    totalTokenSupply,
    totalSupply,
    cashPositionPerTokenUnit,
    balancePerTokenUnit
  });

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

  console.log({
    totalTokenSupply,
    totalSupply,
    cashPositionPerTokenUnit,
    balancePerTokenUnit,
    balancePerTokenUnitContract,
    cashPositionPerTokenUnitContract,
    totalBalance,
    totalCashPosition
  });
})();
