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
const PersistentStorage = contract.fromArtifact("PersistentStorage");
const KYCVerifier = contract.fromArtifact("KYCVerifier");
const CashPool = contract.fromArtifact("CashPool");
const TokenSwapManager = contract.fromArtifact("TokenSwapManager");
const CompositionCalculator = contract.fromArtifact("CompositionCalculator");
const sixtyPercentInArrayFraction = [3, 5];

const getEth = num =>
  new BigNumber(num).times(new BigNumber("10").pow("18")).integerValue();

const getUsdc = num =>
  new BigNumber(num).times(new BigNumber("10").pow("6")).integerValue();

const normalizeUsdc = num =>
  new BigNumber(num).dividedBy(new BigNumber("10").pow("12")).integerValue();

describe("TokenSwapManager", function() {
  const [owner, user, bridge] = accounts;
  const coldStorage = accounts[9];

  beforeEach(async function() {
    // Initialize Persistent Storage
    this.storage = await PersistentStorage.new({ from: owner });
    const managementFee = ether("7");
    const minRebalanceAmount = ether("1");
    const lastMintingFee = ether("0.001");
    const balancePrecision = 12;
    const minimumMintingFee = ether("5");
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
    await this.cashPool.addTokenManager(this.tokenSwapManager.address, {from: owner})

    await this.storage.setBridge(bridge, { from: owner });

    this.timeout(115000);
  });

  describe("#successfulCreateOrder", function() {
    const cashPosition = getEth(2 * 1000 * 1000);
    const balance = getEth(1000);
    const totalTokenSupply = getEth(1);
    const price = getEth(1000);
    const lendingFee = getEth(0);
    const tokensGiven = getEth(10);

    const tokensRecieved = getEth(0.000005);

    beforeEach(async function() {
      await this.kycVerifier.setWhitelistedAddress(user, { from: owner });
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

      this.receipt = await this.tokenSwapManager.createOrder(
        true, // Order Type
        tokensGiven, // Tokens Given
        tokensRecieved, // Tokens Recieved
        2, // Avg Blended Fee
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
        stablecoin: this.stablecoin.address
      });
    });

    it("successfully mint tokens to user address", async function() {
      const balance = await this.inverseToken.balanceOf(user);
      expect(balance.toNumber()).to.be.equal(tokensRecieved.toNumber());
    });
  });

  describe("#unsuccessfulCreateOrder", function() {
    const cashPosition = getEth(2 * 1000 * 1000);
    const balance = getEth(1000);
    const totalTokenSupply = getEth(1);
    const price = getEth(1000);
    const lendingFee = getEth(0);
    const tokensGiven = getEth(10);
    const tokensRecieved = getEth(0.00000997);

    beforeEach(async function() {
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

    it("throws error when user is not whitelisted", async function() {
      await expectRevert(
        this.tokenSwapManager.createOrder(
          true,
          tokensGiven,
          tokensRecieved,
          2,
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
        2,
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
    const cashPosition = getEth(2000);
    const balance = getEth(1);
    const totalTokenSupply = getEth(10);
    const stablecoinsToMint = getEth(10000);
    const price = getEth(1000);
    const spot = getEth(1200);
    const lendingFee = getEth(0);
    const tokensGiven = getEth(1);
    const tokensRecieved = new BigNumber(cashPosition - spot).minus(getEth(5));
    beforeEach(async function() {
      await this.kycVerifier.setWhitelistedAddress(user, { from: owner });
      await this.storage.setAccounting(
        price,
        cashPosition,
        balance,
        lendingFee,
        {
          from: owner
        }
      );

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
        2, // Avg Blended Fee
        spot,
        user, // Whitelisted User
        this.stablecoin.address, // Stablecoin Address
        0,
        { from: bridge } // Sent From Bridge
      );
    });

    it("emits successful order event", async function() {
      expectEvent(this.receipt, "SuccessfulOrder", {
        orderType: "REDEEM",
        whitelistedAddress: user,
        tokensGiven: tokensGiven.toString(),
        tokensRecieved: tokensRecieved.toString(),
        stablecoin: this.stablecoin.address
      });
    });

    it("successfully redeem after creation order", async function() {
      const tokensSent = getEth(15);
      const tokensCreated = getEth(0.01);

      await this.tokenSwapManager.createOrder(
        true,
        tokensSent,
        tokensCreated,
        2,
        price,
        user,
        this.stablecoin.address, // Stablecoin Address
        0,
        { from: bridge }
      );
      const receipt = await this.tokenSwapManager.redeemOrder(
        true,
        tokensCreated,
        getEth(5),
        2,
        price,
        user,
        this.stablecoin.address, // Stablecoin Address
        0,
        { from: bridge }
      );
      expectEvent(receipt, "SuccessfulOrder", {
        orderType: "REDEEM",
        whitelistedAddress: user,
        tokensGiven: String(tokensCreated),
        tokensRecieved: String(getEth(5)),
        stablecoin: this.stablecoin.address
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
    const cashPosition = getEth(2000);
    const balance = getEth(1);
    const totalTokenSupply = getEth(10);
    const stablecoinsToMint = getUsdc(10000);
    const price = getEth(1000);
    const spot = getEth(1200);
    const lendingFee = getEth(0);
    const tokensGiven = getEth(1);
    const tokensRecieved = new BigNumber(cashPosition - spot).minus(getEth(5));

    beforeEach(async function() {
      await this.kycVerifier.setWhitelistedAddress(user, { from: owner });
      await this.storage.setAccounting(
        price,
        cashPosition,
        balance,
        lendingFee,
        {
          from: owner
        }
      );
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
        2, // Avg Blended Fee
        spot,
        user, // Whitelisted User
        this.stablecoin.address, // Stablecoin Address
        0,
        { from: bridge } // Sent From Bridge
      );
    });

    it("executes redemption without settlement", async function() {
      expectEvent(this.receipt, "SuccessfulOrder", {
        orderType: "REDEEM_NO_SETTLEMENT",
        whitelistedAddress: user,
        tokensGiven: tokensGiven.toString(),
        tokensRecieved: tokensRecieved.toString(),
        stablecoin: this.stablecoin.address
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
          2,
          1000,
          user,
          this.stablecoin.address,
          0,
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
        2,
        1000,
        user,
        this.stablecoin.address,
        0,
        {
          from: bridge
        }
      );

      const userReturnedBalance = await this.inverseToken.balanceOf(user);
      expect(userReturnedBalance.toNumber()).to.be.equal(10);
    });
  });

  describe("#dailyRebalance", function() {
    const cashPosition = getEth(2 * 1000 * 1000);
    const balance = getEth(1000);
    const totalTokenSupply = getEth(1);

    beforeEach(async function() {
      await this.inverseToken.mintTokens(owner, totalTokenSupply, {
        from: owner
      });
    });

    it("should keep same values without price change and fee", async function() {
      const price = getEth(1000);
      const lendingFee = getEth(0);
      await this.storage.setAccounting(
        price,
        cashPosition,
        balance,
        lendingFee,
        {
          from: owner
        }
      );
      await time.increase(time.duration.days(1));

      await this.tokenSwapManager.dailyRebalance(
        price,
        lendingFee,
        lendingFee,
        cashPosition,
        balance,
        totalTokenSupply,
        { from: owner }
      );
      const lastActivityDay = await this.storage.lastActivityDay();
      const accounting = await this.storage.getAccounting(
        lastActivityDay.toNumber()
      );

      expect(new BigNumber(accounting[0]).eq(price)).to.be.true;
      expect(new BigNumber(accounting[1]).eq(cashPosition)).to.be.true;
      expect(new BigNumber(accounting[2]).eq(balance)).to.be.true;
      expect(new BigNumber(accounting[3]).eq(lendingFee)).to.be.true;
    });

    it("should decrease by fee with same price", async function() {
      const price = getEth(1000);
      const lendingFee = getEth(365);
      await this.storage.setAccounting(
        price,
        cashPosition,
        balance,
        lendingFee,
        {
          from: owner
        }
      );
      await time.increase(time.duration.days(1));

      const cashPositionMinusFee = "1980000000000000000000000";

      const result = await this.compositionCalculator.calculatePCF(
        cashPosition,
        balance,
        price,
        lendingFee,
        1,
        getEth(0),
        12
      );

      const endBalance = result[1];
      const endCashPosition = result[2];

      await this.tokenSwapManager.dailyRebalance(
        price,
        lendingFee,
        lendingFee,
        cashPositionMinusFee,
        endBalance,
        totalTokenSupply,
        { from: owner }
      );
      const lastActivityDay = await this.storage.lastActivityDay();
      const accounting = await this.storage.getAccounting(
        lastActivityDay.toNumber()
      );

      expect(new BigNumber(accounting[0]).eq(price)).to.be.true;
      expect(new BigNumber(accounting[1]).eq(cashPositionMinusFee)).to.be.true;
      expect(new BigNumber(accounting[2]).eq(endBalance)).to.be.true;
      expect(new BigNumber(accounting[3]).eq(lendingFee)).to.be.true;
    });
    it("should increase when price falls", async function() {
      const price = getEth(900);
      const lendingFee = getEth(365);

      await this.storage.setAccounting(
        price,
        cashPosition,
        balance,
        lendingFee,
        {
          from: owner
        }
      );
      await time.increase(time.duration.days(1));

      const result = await this.compositionCalculator.calculatePCF(
        cashPosition,
        balance,
        price,
        lendingFee,
        1,
        getEth(0),
        12
      );
      const endBalance = result[1];
      const endCashPosition = result[2];

      await this.tokenSwapManager.dailyRebalance(
        price,
        lendingFee,
        lendingFee,
        endCashPosition,
        endBalance,
        totalTokenSupply,
        { from: owner }
      );
      const lastActivityDay = await this.storage.lastActivityDay();
      const accounting = await this.storage.getAccounting(
        lastActivityDay.toNumber()
      );

      expect(new BigNumber(accounting[0]).eq(price)).to.be.true;
      expect(new BigNumber(accounting[1]).eq(endCashPosition)).to.be.true;
      expect(new BigNumber(accounting[2]).eq(endBalance)).to.be.true;
      expect(new BigNumber(accounting[3]).eq(lendingFee)).to.be.true;
      const netTokenValue = await this.compositionCalculator.getCurrentNetTokenValue();
      expect(new BigNumber(netTokenValue).gt(getEth(1000 * 1000))).to.be.true;
    });
    it("should decrease when price falls", async function() {
      const price = getEth(1100);
      const lendingFee = getEth(365);

      await this.storage.setAccounting(
        price,
        cashPosition,
        balance,
        lendingFee,
        {
          from: owner
        }
      );
      await time.increase(time.duration.days(1));

      const result = await this.compositionCalculator.calculatePCF(
        cashPosition,
        balance,
        price,
        lendingFee,
        1,
        getEth(0),
        12
      );
      const endBalance = result[1];
      const endCashPosition = result[2];

      await this.tokenSwapManager.dailyRebalance(
        price,
        lendingFee,
        lendingFee,
        endCashPosition,
        endBalance,
        totalTokenSupply,
        { from: owner }
      );
      const lastActivityDay = await this.storage.lastActivityDay();
      const accounting = await this.storage.getAccounting(
        lastActivityDay.toNumber()
      );

      expect(new BigNumber(accounting[0]).eq(price)).to.be.true;
      expect(new BigNumber(accounting[1]).eq(endCashPosition)).to.be.true;
      expect(new BigNumber(accounting[2]).eq(endBalance)).to.be.true;
      expect(new BigNumber(accounting[3]).eq(lendingFee)).to.be.true;
      const netTokenValue = await this.compositionCalculator.getCurrentNetTokenValue();
      expect(new BigNumber(netTokenValue).lt(getEth(1000 * 1000))).to.be.true;
    });

    it("should throw error when cash positions do not match", async function() {
      const price = getEth(1000);
      const lendingFee = getEth(1);

      await this.storage.setAccounting(
        price,
        cashPosition,
        balance,
        lendingFee,
        {
          from: owner
        }
      );
      await time.increase(time.duration.days(1));

      await expectRevert(
        this.tokenSwapManager.dailyRebalance(
          price,
          lendingFee,
          lendingFee,
          cashPosition,
          balance,
          totalTokenSupply,
          { from: owner }
        ),
        "The cash positions should match."
      );
    });
  });

  describe("#thresholdRebalance", function() {
    const cashPosition = getEth(2 * 1000 * 1000);
    const balance = getEth(1000);
    const totalTokenSupply = getEth(1);

    beforeEach(async function() {
      await this.inverseToken.mintTokens(owner, totalTokenSupply, {
        from: owner
      });
    });
    it("should keep same values without price change and fee", async function() {
      const price = getEth(1000);
      const lendingFee = getEth(0);
      await this.storage.setAccounting(
        price,
        cashPosition,
        balance,
        lendingFee,
        {
          from: owner
        }
      );
      await time.increase(time.duration.days(1));
      await this.tokenSwapManager.thresholdRebalance(
        price,
        lendingFee,
        cashPosition,
        balance,
        totalTokenSupply,
        { from: owner }
      );
      const lastActivityDay = await this.storage.lastActivityDay();
      const accounting = await this.storage.getAccounting(
        lastActivityDay.toNumber()
      );

      expect(new BigNumber(accounting[0]).eq(price)).to.be.true;
      expect(new BigNumber(accounting[1]).eq(cashPosition)).to.be.true;
      expect(new BigNumber(accounting[2]).eq(balance)).to.be.true;
      expect(new BigNumber(accounting[3]).eq(lendingFee)).to.be.true;
    });
    it("should increase when price falls", async function() {
      const price = getEth(900);
      const lendingFee = getEth(365);

      await this.storage.setAccounting(
        price,
        cashPosition,
        balance,
        lendingFee,
        {
          from: owner
        }
      );
      await time.increase(time.duration.days(1));
      const result = await this.compositionCalculator.calculatePCF(
        cashPosition,
        balance,
        price,
        0,
        1,
        getEth(0),
        12
      );
      const endBalance = result[1];
      const endCashPosition = result[2];

      await this.tokenSwapManager.thresholdRebalance(
        price,
        lendingFee,
        endCashPosition,
        endBalance,
        totalTokenSupply,
        { from: owner }
      );
      const lastActivityDay = await this.storage.lastActivityDay();
      const accounting = await this.storage.getAccounting(
        lastActivityDay.toNumber()
      );

      expect(new BigNumber(accounting[0]).eq(price)).to.be.true;
      expect(new BigNumber(accounting[1]).eq(endCashPosition)).to.be.true;
      expect(new BigNumber(accounting[2]).eq(endBalance)).to.be.true;
      expect(new BigNumber(accounting[3]).eq(lendingFee)).to.be.true;
      const netTokenValue = await this.compositionCalculator.getCurrentNetTokenValue();
      expect(new BigNumber(netTokenValue).gt(getEth(1000 * 1000))).to.be.true;
    });
    it("should decrease when price falls", async function() {
      const price = getEth(1100);
      const lendingFee = getEth(365);

      await this.storage.setAccounting(
        price,
        cashPosition,
        balance,
        lendingFee,
        {
          from: owner
        }
      );
      await time.increase(time.duration.days(1));

      const result = await this.compositionCalculator.calculatePCF(
        cashPosition,
        balance,
        price,
        0,
        1,
        getEth(0),
        12
      );
      const endBalance = result[1];
      const endCashPosition = result[2];

      await this.tokenSwapManager.thresholdRebalance(
        price,
        lendingFee,
        endCashPosition,
        endBalance,
        totalTokenSupply,
        { from: owner }
      );
      const lastActivityDay = await this.storage.lastActivityDay();
      const accounting = await this.storage.getAccounting(
        lastActivityDay.toNumber()
      );

      expect(new BigNumber(accounting[0]).eq(price)).to.be.true;
      expect(new BigNumber(accounting[1]).eq(endCashPosition)).to.be.true;
      expect(new BigNumber(accounting[2]).eq(endBalance)).to.be.true;
      expect(new BigNumber(accounting[3]).eq(lendingFee)).to.be.true;
      const netTokenValue = await this.compositionCalculator.getCurrentNetTokenValue();
      expect(new BigNumber(netTokenValue).lt(getEth(1000 * 1000))).to.be.true;
    });

    it("should throw error when cash positions do not match", async function() {
      const price = getEth(1000);
      const lendingFee = getEth(1);

      await this.storage.setAccounting(
        price,
        cashPosition,
        balance,
        lendingFee,
        {
          from: owner
        }
      );
      await time.increase(time.duration.days(1));

      await expectRevert(
        this.tokenSwapManager.thresholdRebalance(
          price,
          lendingFee,
          100,
          balance,
          totalTokenSupply,
          { from: owner }
        ),
        "The cash positions should match."
      );
    });
  });
});
