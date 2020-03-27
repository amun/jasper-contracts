const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");
const {
  expectRevert,
  expectEvent,
  ether
} = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");

const ERC20WithMinting = contract.fromArtifact("InverseToken");
const PersistentStorage = contract.fromArtifact("PersistentStorage");
const KYCVerifier = contract.fromArtifact("KYCVerifier");
const CollateralPool = contract.fromArtifact("CollateralPool");
const TokenSwapManager = contract.fromArtifact("TokenSwapManager");
const CompositionCalculator = contract.fromArtifact("CompositionCalculator");
const sixtyPercentInArrayFraction = [3, 5];

const getEth = num =>
  new BigNumber(num).times(new BigNumber("10").pow("18")).integerValue();

describe("Modifier", function() {
  const [owner, user, bridge] = accounts;
  const coldStorage = accounts[9];

  beforeEach(async function() {
    // Initialize Persistent Storage
    this.storage = await PersistentStorage.new({ from: owner });
    const managementFee = ether("7");
    const minRebalanceAmount = ether("1");
    await this.storage.initialize(owner, managementFee, minRebalanceAmount);
    // Inverse Token + Stablecoin Initialize
    this.inverseToken = await ERC20WithMinting.new({ from: owner });
    await this.inverseToken.initialize(
      "InverseToken",
      "IT",
      18,
      this.storage.address,
      owner
    );

    this.stableCoin = await ERC20WithMinting.new({ from: owner });
    await this.stableCoin.initialize(
      "Stablecoin",
      "USDC",
      18,
      this.storage.address,
      owner
    );

    // Initialize KYC Verifier
    this.kycVerifier = await KYCVerifier.new({ from: owner });
    await this.kycVerifier.initialize(this.storage.address);

    // Deploy Collateral Pool
    this.collateralPool = await CollateralPool.new({ from: owner });
    await this.collateralPool.initialize(
      owner,
      this.kycVerifier.address,
      this.storage.address,
      coldStorage,
      sixtyPercentInArrayFraction
    );

    // Deploy CompositionCalculator
    this.compositionCalculator = await CompositionCalculator.new({
      from: owner
    });
    await this.compositionCalculator.initialize(
      this.storage.address,
      this.inverseToken.address
    );

    // Initialize TSM
    this.tokenSwapManager = await TokenSwapManager.new({ from: owner });
    await this.tokenSwapManager.initialize(
      owner,
      this.stableCoin.address,
      this.inverseToken.address,
      this.storage.address,
      this.kycVerifier.address,
      this.collateralPool.address,
      this.compositionCalculator.address
    );
    await this.storage.setTokenSwapManager(this.tokenSwapManager.address, {
      from: owner
    });
    await this.storage.setBridge(bridge, { from: owner });

    this.timeout(115000);
  });

  describe("#tokenSwapManager", function() {
    const cashPosition = getEth(2 * 1000 * 1000);
    const balance = getEth(1000);
    const totalTokenSupply = getEth(1);
    const price = getEth(1000);
    const lendingFee = getEth(0);
    const tokensGiven = getEth(10);
    const tokensRecieved = getEth(0.00000997);

    beforeEach(async function() {
      await this.storage.setWhitelistedAddress(user, { from: owner });
      await this.inverseToken.mintTokens(owner, totalTokenSupply, {
        from: owner
      });
      await this.storage.setAccounting(
        price,
        cashPosition,
        balance,
        lendingFee,
        {
          from: owner
        }
      );
    });

    it("successfully place create order from bridge", async function() {
      this.reciept = await this.tokenSwapManager.createOrder(
        "SUCCESS", // Order Type
        tokensGiven, // Tokens Given
        tokensRecieved, // Tokens Recieved
        2, // Avg Blended Fee
        price,
        user, // Whitelisted User
        { from: bridge } // Sent From Bridge
      );

      expectEvent(this.reciept, "SuccessfulOrder", {
        orderType: "CREATE",
        whitelistedAddress: user,
        tokensGiven: tokensGiven.toString(),
        tokensRecieved: tokensRecieved.toString()
      });
    });

    it("unsuccessfully place create order from user", async function() {
      await expectRevert(
        this.tokenSwapManager.createOrder(
          "SUCCESS",
          tokensGiven,
          tokensRecieved,
          2,
          price,
          user,
          { from: user }
        ),
        "caller is not the owner or bridge"
      );
    });

    it("pauses create orders", async function() {
      await this.storage.setIsPaused(true, { from: owner });
      await expectRevert(
        this.tokenSwapManager.createOrder(
          "SUCCESS",
          tokensGiven,
          tokensRecieved,
          2,
          price,
          user,
          { from: bridge }
        ),
        "contract is paused"
      );
    });

    it("un-pauses create orders", async function() {
      await this.storage.setIsPaused(true, { from: owner });
      await this.storage.setIsPaused(false, { from: owner });
      await this.tokenSwapManager.createOrder(
        "SUCCESS",
        tokensGiven,
        tokensRecieved,
        2,
        price,
        user,
        { from: bridge }
      );
    });

    it("shuts down contract", async function() {
      await this.storage.setIsShutdown({ from: owner });
      await expectRevert(
        this.tokenSwapManager.createOrder(
          "SUCCESS",
          tokensGiven,
          tokensRecieved,
          2,
          price,
          user,
          { from: bridge }
        ),
        "contract is shutdown"
      );
    });
  });

  describe("#inverseToken", function() {
    beforeEach(async function() {
      await this.storage.setWhitelistedAddress(user, { from: owner });
    });

    it("mints token from owner", async function() {
      await this.inverseToken.mintTokens(user, 10, { from: owner });

      const userBalance = await this.inverseToken.balanceOf(user);
      expect(userBalance.toNumber()).to.be.equal(10);
    });

    it("burns token from owner", async function() {
      await this.inverseToken.mintTokens(user, 10, { from: owner });
      await this.inverseToken.burnTokens(user, 5, { from: owner });

      const userBalance = await this.inverseToken.balanceOf(user);
      expect(userBalance.toNumber()).to.be.equal(5);
    });

    it("cannot mint/burn token from unauthorized user", async function() {
      await expectRevert(
        this.inverseToken.mintTokens(user, 10, { from: user }),
        "caller is not the owner or token swap manager"
      );
      await expectRevert(
        this.inverseToken.burnTokens(user, 10, { from: user }),
        "caller is not the owner or token swap manager"
      );
    });
  });

  describe("#collateralPool", function() {
    beforeEach(async function() {
      await this.storage.setWhitelistedAddress(user, { from: owner });
    });

    it("allows owner to move tokens from pool", async function() {
      await this.inverseToken.mintTokens(this.collateralPool.address, 10, {
        from: owner
      });
      await this.collateralPool.moveTokenfromPool(
        this.inverseToken.address,
        user,
        5,
        { from: owner }
      );

      const userBalance = await this.inverseToken.balanceOf(user);
      expect(userBalance.toNumber()).to.be.equal(5);
    });

    it("does not allow user to move tokens from pool", async function() {
      await this.inverseToken.mintTokens(this.collateralPool.address, 10, {
        from: owner
      });

      await expectRevert(
        this.collateralPool.moveTokenfromPool(
          this.inverseToken.address,
          bridge,
          5,
          { from: user }
        ),
        "caller is not the owner or token swap manager"
      );
    });
  });
});
