const fs = require('fs');
const path = require('path');
const Web3 = require('web3');
const web3 = new Web3('http://127.0.0.1:8545');

(async () => {
  const accounts = await web3.eth.getAccounts();
  const ownerAddress = accounts[0];

  // Get USDC address from filesystem
  let contractsAddresses = fs.readFileSync('/tmp/contractsAddresses.json');
  contractsAddresses = JSON.parse(contractsAddresses);
  if (!Object.values(contractsAddresses).every(val => val)) {
    throw new Error('Some of the contract deployments didn\'t work well. Try rerun the contracts reset script')
  }
  const usdcAddress = contractsAddresses.USDC;

  // Get USDC abi from filesystem
  const abisDir = path.join(__dirname, '../', 'build', 'contracts');
  const usdcJsonPath = path.join(abisDir, 'USDC.json');
  let usdcJsonContent = fs.readFileSync(usdcJsonPath);
  usdcJsonContent = JSON.parse(usdcJsonContent);
  const usdcAbi = usdcJsonContent.abi;
  const usdcContract = new web3.eth.Contract(usdcAbi, usdcAddress);

  // console.log(usdcContract.methods);
  await usdcContract.methods.unpause().send({ from: ownerAddress, gasPrice: 1, gas: 121272 });

  let gasEstimate = await usdcContract.methods.configureMinter(ownerAddress, '1000000000000000000000000').estimateGas({ from: ownerAddress });
  // Allowing minter to mint 1M USDC
  await usdcContract.methods.configureMinter(ownerAddress, '1000000000000000000000000').send({from: ownerAddress, gasPrice: 1, gas: gasEstimate });
  // mint
  gasEstimate = await usdcContract.methods.mint(ownerAddress, '10000000000000000000000').estimateGas({ from: ownerAddress });
  await usdcContract.methods.mint(ownerAddress, '10000000000000000000000').send({from: ownerAddress, gasPrice: 1, gas: gasEstimate});
  console.log('Finished minting');
  const balance = await usdcContract.methods.balanceOf(ownerAddress).call();
  console.log(`Your current balance is ${Number(balance) / 1e18} USDC`);
  console.log("Godspeed\n")
  fs.readFile(path.join(__dirname, 'amun-ascii.txt'), {encoding: 'utf-8'}, (err, data) => {
    if (!err) {
        console.log(data);
    }
  });
})();