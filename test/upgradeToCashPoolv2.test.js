// Skip this test - for reference material only
const Web3 = require("web3");
const { provider } = require("@openzeppelin/test-environment");
const {
  Contracts,
  ZWeb3,
  SimpleProject,
} = require("@openzeppelin/upgrades");
const { ether, expectRevert } = require("@openzeppelin/test-helpers");

const { expect } = require("chai");

describe.skip("CashPoolv2", async function() {
  this.timeout(50000);

  beforeEach(async function() {
    // Create web3 provider
    const web3 = new Web3(provider);
    ZWeb3.initialize(web3.currentProvider);

    [
      this.proxyAdmin,
      this.owner,
      this.user,
      this.anotherUser,
      this.tokenSwap,
      this.coldStorage,
      this.tokenManager1,
      this.tokenManager2,
      this.user,
    ] = await web3.eth.getAccounts();

    const CashPool = Contracts.getFromLocal("CashPool");
    const CashPoolv2 = Contracts.getFromLocal("CashPoolv2");
    const ERC20WithMinting = Contracts.getFromLocal("InverseToken");
    const PersistentStorage = Contracts.getFromLocal("PersistentStorage");
    const KYCVerifier = Contracts.getFromLocal("KYCVerifier");
    const sixtyPercentInArrayFraction = [3, 5];

    this.amountOfTokensToPool = 5;
    this.userResultTokenBalance = "15"; // 10 from minting plus 5 from amountOfTokensToPool when transfer happens in tests

    // Create an OpenZeppelin project
    const project = new SimpleProject(
      "BTCShort",
      {},
      { from: this.proxyAdmin }
    );

    // Initialize Params for Persistent Storage
    const managementFee = ether("7").toString();
    const minRebalanceAmount = ether("1").toString();
    const lastMintingFee = ether("0.001").toString();
    const balancePrecision = 12;
    const minimumMintingFee = ether("5").toString();
    const minimumTrade = ether("50").toString();

    // Deploy an instance of Persistent Storage
    this.persistentStorage = await project.createProxy(PersistentStorage, {
      packageName: null,
      contractName: "PersistentStorage",
      initMethod: "initialize",
      initArgs: [
        this.owner,
        managementFee,
        minRebalanceAmount,
        balancePrecision,
        lastMintingFee,
        minimumMintingFee,
        minimumTrade,
      ],
    });

    // Set 0.2%
    await this.persistentStorage.methods
      .addMintingFeeBracket(
        ether("100000").toString(),
        ether("0.002").toString()
      )
      .send({ from: this.owner });
    await this.persistentStorage.methods
      .setTokenSwapManager(this.tokenSwap)
      .send({ from: this.owner });

    // Deploy an instance of the Token
    this.token = await project.createProxy(ERC20WithMinting, {
      packageName: null,
      contractName: "InverseToken",
      initMethod: "initialize",
      initArgs: [
        "Test Token",
        "TT",
        18,
        this.persistentStorage.address,
        this.owner,
      ],
    });
    // Mint Tokens
    await this.token.methods
      .mintTokens(this.user, 10)
      .send({ from: this.owner });

    // Deploy an instance of Kyc Verfier
    this.kycVerifier = await project.createProxy(KYCVerifier, {
      packageName: null,
      contractName: "KYCVerifier",
      initMethod: "initialize",
      initArgs: [this.owner],
    });
    await this.kycVerifier.methods
      .setWhitelistedAddress(this.user)
      .send({ from: this.owner });

    // Deploy Cash Pool
    this.cashPool = await project.createProxy(CashPool, {
      packageName: null,
      contractName: "CashPool",
      initMethod: "initialize",
      initArgs: [
        this.owner,
        this.kycVerifier.address,
        this.persistentStorage.address,
        this.coldStorage,
        sixtyPercentInArrayFraction,
      ],
    });

    // Upgrade to Cash Pool v2
    this.cashPoolv2 = await project.upgradeProxy(
      this.cashPool.options.address,
      CashPoolv2,
      {
        packageName: null,
        contractName: "CashPoolv2",
        initMethod: null,
        initArgs: null,
      }
    );
    // Add Token Manager 2 to the Mapping
    await this.cashPoolv2.methods
      .addTokenManager(this.tokenManager2)
      .send({ from: this.owner });
  });

  it("maintains the owner address after upgrade", async function() {
    const implementationOwner = await this.cashPoolv2.methods
      .owner()
      .call({ from: this.owner });
    expect(this.owner).to.be.equal(implementationOwner);
  });

  it("maintains the proxy address after upgrade", async function() {
    const upgradeAddress = this.cashPoolv2.options.address;
    expect(this.cashPool.options.address).to.be.equal(upgradeAddress);
  });

  it("adds token manager address to mapping", async function() {
    await this.cashPoolv2.methods
      .addTokenManager(this.tokenManager1)
      .send({ from: this.owner });
    const isAdded = await this.cashPoolv2.methods
      .isTokenManager(this.tokenManager1)
      .call({ from: this.owner });
    expect(isAdded).to.be.equal(true);
  });

  it("removes token manager address from mapping", async function() {
    await this.cashPoolv2.methods
      .removeTokenManager(this.tokenManager2)
      .send({ from: this.owner });
    const isRemoved = await this.cashPoolv2.methods
      .isTokenManager(this.tokenManager2)
      .call({ from: this.owner });
    expect(isRemoved).to.be.equal(false);
  });

  it("moves tokens to pool", async function() {
    await this.token.methods
      .approve(this.cashPoolv2.options.address, this.amountOfTokensToPool)
      .send({ from: this.user });

    await this.cashPoolv2.methods
      .moveTokenToPoolv2(
        this.token.options.address,
        this.user,
        this.amountOfTokensToPool
      )
      .send({ from: this.owner, gas: 6500000 });

    const poolFundsInTokens = await this.token.methods
      .balanceOf(this.cashPoolv2.options.address)
      .call({ from: this.owner });
    const coldStorageAddress = await this.cashPoolv2.methods
      .coldStorage()
      .call({ from: this.owner });
    const coldStorageTokens = await this.token.methods
      .balanceOf(coldStorageAddress)
      .call({ from: this.owner });

    expect(poolFundsInTokens).to.be.bignumber.equal(
      (this.amountOfTokensToPool - coldStorageTokens).toString()
    );
  });

  it("moves tokens to pool from approved token manager", async function() {
    await this.token.methods
      .approve(this.cashPoolv2.options.address, this.amountOfTokensToPool)
      .send({ from: this.user });

    await this.cashPoolv2.methods
      .moveTokenToPoolv2(
        this.token.options.address,
        this.user,
        this.amountOfTokensToPool
      )
      .send({ from: this.tokenManager2, gas: 6500000 });

    const poolFundsInTokens = await this.token.methods
      .balanceOf(this.cashPoolv2.options.address)
      .call({ from: this.owner });
    const coldStorageAddress = await this.cashPoolv2.methods
      .coldStorage()
      .call({ from: this.owner });
    const coldStorageTokens = await this.token.methods
      .balanceOf(coldStorageAddress)
      .call({ from: this.owner });

    expect(poolFundsInTokens).to.be.bignumber.equal(
      (this.amountOfTokensToPool - coldStorageTokens).toString()
    );
  });

  it("rejects movement of tokens to pool from non-approved token manager", async function() {
    await this.token.methods
      .approve(this.cashPoolv2.options.address, this.amountOfTokensToPool)
      .send({ from: this.user });

    await expectRevert(
      this.cashPoolv2.methods
        .moveTokenToPoolv2(
          this.token.options.address,
          this.user,
          this.amountOfTokensToPool
        )
        .send({ from: this.tokenManager1, gas: 6500000 }),
      "caller is not the owner or an approved token swap manager"
    );
  });

  it("moves tokens from pool (by owner)", async function() {
    await this.token.methods
      .mintTokens(this.cashPoolv2.options.address, 10)
      .send({ from: this.owner });

    await this.cashPoolv2.methods
      .moveTokenfromPoolv2(
        this.token.options.address,
        this.user,
        this.amountOfTokensToPool
      )
      .send({ from: this.owner, gas: 6500000 });

    const userBalance = await this.token.methods
      .balanceOf(this.user)
      .call({ from: this.owner });
    expect(userBalance.toString()).to.be.bignumber.equal(
      this.userResultTokenBalance
    );
  });

  it("moves tokens from pool (by approved token manager)", async function() {
    await this.token.methods
      .mintTokens(this.cashPoolv2.options.address, 10)
      .send({ from: this.owner });

    await this.cashPoolv2.methods
      .moveTokenfromPoolv2(
        this.token.options.address,
        this.user,
        this.amountOfTokensToPool
      )
      .send({ from: this.tokenManager2, gas: 6500000 });

    const userBalance = await this.token.methods
      .balanceOf(this.user)
      .call({ from: this.owner });
    expect(userBalance.toString()).to.be.bignumber.equal(
      this.userResultTokenBalance
    );
  });

  it("rejects movement of tokens from pool (by non-approved token manager)", async function() {
    await this.token.methods
      .mintTokens(this.cashPoolv2.options.address, 10)
      .send({ from: this.owner });

    await expectRevert(
      this.cashPoolv2.methods
        .moveTokenfromPoolv2(
          this.token.options.address,
          this.user,
          this.amountOfTokensToPool
        )
        .send({ from: this.tokenManager1, gas: 6500000 }),
      "caller is not the owner or an approved token swap manager"
    );
  });

  it("moves tokens to pool (v1 code)", async function() {
    await this.token.methods
      .approve(this.cashPoolv2.options.address, this.amountOfTokensToPool)
      .send({ from: this.user });

    await this.cashPoolv2.methods
      .moveTokenToPool(
        this.token.options.address,
        this.user,
        this.amountOfTokensToPool
      )
      .send({ from: this.tokenSwap, gas: 6500000 });

    const poolFundsInTokens = await this.token.methods
      .balanceOf(this.cashPoolv2.options.address)
      .call({ from: this.owner });
    const coldStorageAddress = await this.cashPoolv2.methods
      .coldStorage()
      .call({ from: this.owner });
    const coldStorageTokens = await this.token.methods
      .balanceOf(coldStorageAddress)
      .call({ from: this.owner });

    expect(poolFundsInTokens).to.be.bignumber.equal(
      (this.amountOfTokensToPool - coldStorageTokens).toString()
    );
  });

  it("moves tokens from pool (v1 code)", async function() {
    await this.token.methods
      .mintTokens(this.cashPoolv2.options.address, 10)
      .send({ from: this.owner });

    await this.cashPoolv2.methods
      .moveTokenfromPool(
        this.token.options.address,
        this.user,
        this.amountOfTokensToPool
      )
      .send({ from: this.tokenSwap, gas: 6500000 });

    const userBalance = await this.token.methods
      .balanceOf(this.user)
      .call({ from: this.owner });
    expect(userBalance.toString()).to.be.bignumber.equal(
      this.userResultTokenBalance
    );
  });
});
