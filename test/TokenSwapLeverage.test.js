const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");
const {
  expectRevert,
  expectEvent,
  time,
  ether
} = require("@openzeppelin/test-helpers");

const BigNumber = require("bignumber.js");

const ERC20WithMinting = contract.fromArtifact("InverseToken");
const PersistentStorage = contract.fromArtifact("StorageLeverage");
const KYCVerifier = contract.fromArtifact("KYCVerifier");
const CashPool = contract.fromArtifact("CashPool");
const TokenSwapManager = contract.fromArtifact("TokenSwapLeverage");
const CompositionCalculator = contract.fromArtifact("CalculatorLeverage");
const sixtyPercentInArrayFraction = [3, 5];

const getEth = num =>
  new BigNumber(num).times(new BigNumber("10").pow("18")).integerValue();

const getUsdc = num =>
  new BigNumber(num).times(new BigNumber("10").pow("6")).integerValue();

const normalizeUsdc = num =>
  new BigNumber(num).dividedBy(new BigNumber("10").pow("12")).integerValue();

describe("TokenSwapLeverage", async function() {
  const [owner, user, bridge] = accounts;
  const coldStorage = accounts[9];

  beforeEach(async function() {
    // Initialize Persistent Storage
    this.storage = await PersistentStorage.new({ from: owner });
    const managementFee = ether("10.95");
    const minRebalanceAmount = ether("1");
    const lastMintingFee = ether("0.001");
    const balancePrecision = 12;
    const minimumMintingFee = ether("0");
    const minimumTrade = ether("50");

    await this.storage.initialize(
      owner,
      managementFee,
      minRebalanceAmount,
      balancePrecision,
      lastMintingFee,
      minimumMintingFee,
      minimumTrade
    );
    await this.storage.addMintingFeeBracket(ether("50000"), ether("0.003"), {
      from: owner
    }); //0.3%
    await this.storage.addMintingFeeBracket(ether("100000"), ether("0.002"), {
      from: owner
    }); //0.2%
    // Inverse Token + Stablecoin Initialize
    this.inverseToken = await ERC20WithMinting.new({ from: owner });
    await this.inverseToken.initialize(
      "InverseToken",
      "IT",
      18,
      this.storage.address,
      owner
    );

    this.stablecoin = await ERC20WithMinting.new({ from: owner });
    await this.stablecoin.initialize(
      "Stablecoin",
      "USDC",
      6,
      this.storage.address,
      owner
    );

    // Initialize KYC Verifier
    this.kycVerifier = await KYCVerifier.new({ from: owner });
    await this.kycVerifier.initialize(owner);

    // Initialize Cash Pool
    this.cashPool = await CashPool.new({ from: owner });
    await this.cashPool.initialize(
      owner,
      this.kycVerifier.address,
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
      this.inverseToken.address,
      this.cashPool.address,
      this.storage.address,
      this.compositionCalculator.address
    );
    await this.storage.setTokenSwapManager(this.tokenSwapManager.address, {
      from: owner
    });
    await this.cashPool.addTokenManager(this.tokenSwapManager.address, {
      from: owner
    });

    await this.storage.setBridge(bridge, { from: owner });

    this.timeout(11500000);
  });

  describe("#successfulCreateOrder", function() {
    const totalTokenSupply = getEth(1);
    const price = getEth(1000);
    const tokensGiven = getEth(10);
    const tokensRecieved = getEth(0.00997);

    beforeEach(async function() {
      await this.kycVerifier.setWhitelistedAddress(user, { from: owner });
      await this.inverseToken.mintTokens(owner, totalTokenSupply, {
        from: owner
      });

      this.receipt = await this.tokenSwapManager.createOrder(
        true, // Order Type
        tokensGiven, // Tokens Given
        tokensRecieved, // Tokens Recieved
        price,
        user, // Whitelisted User
        this.stablecoin.address, // Stablecoin Address
        0,
        { from: bridge } // Sent From Bridge
      );
    });

    it("emits successful order event", async function() {
      expectEvent(this.receipt, "SuccessfulOrder", {
        orderType: "CREATE",
        whitelistedAddress: user,
        tokensGiven: tokensGiven.toString(),
        tokensRecieved: tokensRecieved.toString(),
        stablecoin: this.stablecoin.address,
        price: "1000000000000000000000"
      });
    });

    it("successfully mint tokens to user address", async function() {
      const balance = await this.inverseToken.balanceOf(user);
      expect(balance.toString()).to.be.equal(tokensRecieved.toString());
    });
  });

  describe("#unsuccessfulCreateOrder", function() {
    const totalTokenSupply = getEth(1);
    const price = getEth(1000);
    const tokensGiven = getEth(10);
    const tokensRecieved = getEth(0.00000997);

    beforeEach(async function() {
      await this.inverseToken.mintTokens(owner, totalTokenSupply, {
        from: owner
      });
    });

    it("throws error when user is not whitelisted", async function() {
      await expectRevert(
        this.tokenSwapManager.createOrder(
          true,
          tokensGiven,
          tokensRecieved,
          price,
          user,
          this.stablecoin.address, // Stablecoin Address
          0,
          { from: bridge }
        ),
        "only whitelisted address may place orders"
      );
    });

    it("throws error from trading engine: return user funds", async function() {
      const usdcAmount = getUsdc(10);
      const usdcAmountWithDecimals = getEth(10);
      await this.kycVerifier.setWhitelistedAddress(user, { from: owner });
      await this.stablecoin.mintTokens(this.cashPool.address, usdcAmount, {
        from: owner
      });
      await this.tokenSwapManager.createOrder(
        false,
        usdcAmountWithDecimals,
        usdcAmountWithDecimals,
        price,
        user,
        this.stablecoin.address, // Stablecoin Address
        0,
        {
          from: bridge
        }
      );

      const userReturnedBalance = await this.stablecoin.balanceOf(user);
      expect(userReturnedBalance.toString()).to.be.equal(usdcAmount.toString());
    });
  });

  describe("#successfulRedemptionOrders", function() {
    const totalTokenSupply = getEth(100);
    const stablecoinsToMint = getEth(10000);

    const price = getEth(1000);
    const tokensGiven = getEth(10);
    const tokensRecieved = getEth(9969.875375);
    const timeElapsed = getEth(1);


    beforeEach(async function() {
      await this.kycVerifier.setWhitelistedAddress(user, { from: owner });

      await this.inverseToken.mintTokens(
        this.cashPool.address,
        totalTokenSupply,
        {
          from: owner
        }
      );

      await this.stablecoin.mintTokens(
        this.cashPool.address,
        stablecoinsToMint,
        {
          from: owner
        }
      );

      this.receipt = await this.tokenSwapManager.redeemOrder(
        true, // Order Type
        tokensGiven, // Tokens Given
        tokensRecieved, // Tokens Recieved
        price,
        user, // Whitelisted User
        this.stablecoin.address, // Stablecoin Address
        0,
        timeElapsed,
        { from: bridge } // Sent From Bridge
      );
    });

    it("emits successful order event", async function() {
      expectEvent(this.receipt, "SuccessfulOrder", {
        orderType: "REDEEM",
        whitelistedAddress: user,
        tokensGiven: tokensGiven.toString(),
        tokensRecieved: "9969875375000000000000",
        stablecoin: this.stablecoin.address,
        price: "1000000000000000000000"
      });
    });

    it("successfully redeem after creation order", async function() {
      const tokensSent = getEth(10);
      const tokensCreated = getEth(0.00997);

      await this.tokenSwapManager.createOrder(
        true,
        tokensSent,
        tokensCreated,
        price,
        user,
        this.stablecoin.address, // Stablecoin Address
        0,
        { from: bridge }
      );
      const receipt = await this.tokenSwapManager.redeemOrder(
        true,
        tokensGiven,
        tokensRecieved,
        price,
        user,
        this.stablecoin.address, // Stablecoin Address
        0,
        timeElapsed,
        { from: bridge }
      );
      expectEvent(receipt, "SuccessfulOrder", {
        orderType: "REDEEM",
        whitelistedAddress: user,
        tokensGiven: tokensGiven.toString(),
        tokensRecieved: "9969875375000000000000",
        stablecoin: this.stablecoin.address,
        price: "1000000000000000000000"
      });
    });

    it("successfully burn tokens from cash pool", async function() {
      const balance = await this.inverseToken.balanceOf(this.cashPool.address);
      expect(balance.toString()).to.be.equal(
        new BigNumber(totalTokenSupply).minus(tokensGiven).toString()
      );
    });
  });

  describe("#delayedRedemptionOrder", function() {
    const totalTokenSupply = getEth(100);
    const stablecoinsToMint = getUsdc(10000);

    const price = getEth(1000);
    const tokensGiven = getEth(10);
    const tokensRecieved = getEth(9969.875375);
    const timeElapsed = getEth(1);


    beforeEach(async function() {
      await this.kycVerifier.setWhitelistedAddress(user, { from: owner });
      await this.inverseToken.mintTokens(
        this.cashPool.address,
        totalTokenSupply,
        {
          from: owner
        }
      );

      this.receipt = await this.tokenSwapManager.redeemOrder(
        true, // Order Type
        tokensGiven, // Tokens Given
        tokensRecieved, // Tokens Recieved
        price,
        user, // Whitelisted User
        this.stablecoin.address, // Stablecoin Address
        0,
        timeElapsed,
        { from: bridge } // Sent From Bridge
      );
    });

    it("executes redemption without settlement", async function() {
      expectEvent(this.receipt, "SuccessfulOrder", {
        orderType: "REDEEM_NO_SETTLEMENT",
        whitelistedAddress: user,
        tokensGiven: tokensGiven.toString(),
        tokensRecieved: "9969875375000000000000",
        stablecoin: this.stablecoin.address,
        price: "1000000000000000000000"
      });
    });

    it("settles redemption at a later date", async function() {
      await this.stablecoin.mintTokens(
        this.cashPool.address,
        stablecoinsToMint,
        { from: owner }
      );
      await this.tokenSwapManager.settleDelayedFunds(
        tokensRecieved,
        user,
        this.stablecoin.address,
        {
          from: bridge
        }
      );
      const balance = await this.stablecoin.balanceOf(user);
      const normalizedUSDC = normalizeUsdc(tokensRecieved);
      expect(balance.toString()).to.be.equal(normalizedUSDC.toString());
    });
  });

  describe("#unsuccessfulRedemptionOrder", function() {
    it("throws error when user is not whitelisted", async function() {
      await expectRevert(
        this.tokenSwapManager.redeemOrder(
          true,
          10,
          10,
          1000,
          user,
          this.stablecoin.address,
          0,
          1,
          {
            from: bridge
          }
        ),
        "only whitelisted address may place orders"
      );
    });

    it("throws error from trading engine: return user funds", async function() {
      await this.kycVerifier.setWhitelistedAddress(user, { from: owner });
      await this.inverseToken.mintTokens(this.cashPool.address, 10, {
        from: owner
      });
      await this.tokenSwapManager.redeemOrder(
        false,
        10,
        10,
        1000,
        user,
        this.stablecoin.address,
        0,
        1,
        {
          from: bridge
        }
      );

      const userReturnedBalance = await this.inverseToken.balanceOf(user);
      expect(userReturnedBalance.toNumber()).to.be.equal(10);
    });
  });
});
