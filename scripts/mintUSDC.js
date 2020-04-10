const fs = require("fs");
const path = require("path");
const Web3 = require("web3");
const web3 = new Web3("http://127.0.0.1:8545");

let contractsAddresses = fs.readFileSync("/tmp/contractsAddresses.json");
contractsAddresses = JSON.parse(contractsAddresses);

const abisDir = path.join(__dirname, "../", "build", "contracts");

if (!Object.values(contractsAddresses).every((val) => val)) {
  throw new Error(
    "Some of the contract deployments didn't work well. Try rerun the contracts reset script"
  );
}

function encodeFunction(abiArray, functionName, functionArgs) {
  for (const object of abiArray)
    if (object.name == functionName)
      return web3.eth.abi.encodeFunctionCall(object, functionArgs);
  throw new Error("function " + functionName + " does not exist");
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

(async () => {
  const isDappMode = process.argv.length > 2 && process.argv[2] === 'true';
  const accounts = await web3.eth.getAccounts();
  const mainAccount = accounts[0];

  // Get USDC address from filesystem
  const usdcContract = getContract("USDC");

  if (isDappMode) {
    console.log('in isDappMode');
    const multiSigContract = getContract("OwnerMultiSig");
    const ownerMultiSigAddress = multiSigContract.options.address;

    // unpause
    const encodedUnpause = encodeFunction(
      getContractAbi("USDC"),
      "unpause",
      []
    );
    await multiSigContract.methods
      .submitTransaction(usdcContract.options.address, 0, encodedUnpause)
      .send({ from: mainAccount, gasPrice: 1, gas: 1212720 });

    // minter - Allowing minter to mint 1M USDC
    const encodedConfigureMinter = encodeFunction(
      getContractAbi("USDC"),
      "configureMinter",
      [ownerMultiSigAddress, web3.utils.toWei("1000000", "mwei")]
    );
    await multiSigContract.methods
      .submitTransaction(
        usdcContract.options.address,
        0,
        encodedConfigureMinter
      )
      .send({ from: mainAccount, gasPrice: 1, gas: 1212720 });

    // mint
    const encodedMint = encodeFunction(getContractAbi("USDC"), "mint", [
      mainAccount,
      web3.utils.toWei("10000", "mwei"),
    ]);
    await multiSigContract.methods
      .submitTransaction(usdcContract.options.address, 0, encodedMint)
      .send({ from: mainAccount, gasPrice: 1, gas: 1212720 });

    console.log("Finished minting USDC");
    const balance = await usdcContract.methods.balanceOf(mainAccount).call();
    console.log(
      `Your current balance is ${web3.utils.fromWei(balance, "mwei")} USDC`
    );
    console.log("Godspeed\n");
    fs.readFile(
      path.join(__dirname, "amun-ascii.txt"),
      { encoding: "utf-8" },
      (err, data) => {
        if (!err) {
          console.log(data);
        }
      }
    );
  } else {
    // contracts only mode

    await usdcContract.methods
      .unpause()
      .send({ from: mainAccount, gasPrice: 1, gas: 121272 });

    let gasEstimate = await usdcContract.methods
      .configureMinter(mainAccount, "1000000000000000000000000")
      .estimateGas({ from: mainAccount });
    // Allowing minter to mint 1M USDC
    await usdcContract.methods
      .configureMinter(mainAccount, web3.utils.toWei("1000000", "mwei"))
      .send({ from: mainAccount, gasPrice: 1, gas: gasEstimate });
    // mint
    gasEstimate = await usdcContract.methods
      .mint(mainAccount, web3.utils.toWei("10000", "mwei"))
      .estimateGas({ from: mainAccount });
    await usdcContract.methods
      .mint(mainAccount, web3.utils.toWei("10000", "mwei"))
      .send({ from: mainAccount, gasPrice: 1, gas: gasEstimate });
    console.log("Finished minting");
    const balance = await usdcContract.methods.balanceOf(mainAccount).call();
    console.log(
      `Your current balance is ${web3.utils.fromWei(balance, "mwei")} USDC`
    );
    console.log("Godspeed\n");
    fs.readFile(
      path.join(__dirname, "amun-ascii.txt"),
      { encoding: "utf-8" },
      (err, data) => {
        if (!err) {
          console.log(data);
        }
      }
    );
  }
})();
