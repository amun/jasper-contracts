const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");
const { expectRevert, expectEvent, time } = require("@openzeppelin/test-helpers");

const BigNumber = require("bignumber.js");

const ERC20WithMinting = contract.fromArtifact("InverseToken");
const PersistentStorage = contract.fromArtifact("PersistentStorage");
const KYCVerifier = contract.fromArtifact("KYCVerifier");
const CollateralPool = contract.fromArtifact("CollateralPool");
const TokenSwapManager = contract.fromArtifact("TokenSwapManager");
const CompositionCalculator = contract.fromArtifact("CompositionCalculator");



const getEth = (num) => (new BigNumber(num).times(new BigNumber('10').pow('18'))).integerValue();


describe("TokenSwapManager", function() {

  const [owner, user, bridge] = accounts;

  beforeEach(async function() {
    // Inverse Token + Stablecoin Initialize
    this.inverseToken = await ERC20WithMinting.new({ from: owner });
    await this.inverseToken.initialize("InverseToken", "IT", 18);

    this.stableCoin = await ERC20WithMinting.new({ from: owner });
    await this.stableCoin.initialize("Stablecoin", "USDC", 18);

    // Initialize Persistent Storage
    this.storage = await PersistentStorage.new({ from: owner });
    await this.storage.initialize(owner);
    
    
    // Initialize KYC Verifier
    this.kycVerifier = await KYCVerifier.new({ from: owner });
    await this.kycVerifier.initialize(this.storage.address);

    // Deploy Collateral Pool
    this.collateralPool = await CollateralPool.new({ from: owner });

    // Deploy CompositionCalculator
    this.compositionCalculator = await CompositionCalculator.new({ from: owner });
    await this.compositionCalculator.initialize(this.storage.address, this.inverseToken.address);

    // Initialize TSM
    this.tokenSwapManager = await TokenSwapManager.new({ from: owner });
    await this.tokenSwapManager.initialize(
      bridge, 
      this.stableCoin.address,
      this.inverseToken.address,
      this.storage.address,
      this.kycVerifier.address,
      this.collateralPool.address,
      this.compositionCalculator.address
    );
    await this.storage.setTokenSwapManager(this.tokenSwapManager.address, { from: owner });

    // Initialize Collateral Pool 
    await this.collateralPool.initialize(this.tokenSwapManager.address, this.kycVerifier.address);

    this.timeout(115000);

  });

  describe("#successfulCreateOrder", function () {

    beforeEach(async function () {
      await this.storage.setWhitelistedAddress(user, { from: owner }); 
      this.reciept = await this.tokenSwapManager.createOrder(
        'SUCCESS',       // Order Type
        '',              // Order Message 
        10,              // Tokens Given
        10,              // Tokens Recieved
        2,               // Avg Blended Fee
        user,            // Whitelisted User 
        { from: bridge } // Sent From Bridge 
      ); 

    });

    it("emits successful order event", async function() {
      expectEvent(this.reciept, "SuccessfulOrder", {
        orderType: "CREATE",
        whitelistedAddress: user,
        tokensGiven: "10",
        tokensRecieved: "10"
      });
    });
    
    it("locks tokens from creation order", async function() {
      const lockedTokens = await this.tokenSwapManager.getLockedAmount(user, {from: user});
      expect(lockedTokens.toNumber()).to.be.equal(10);

    });

    it("locks tokens from multiple creation orders", async function() {
      await this.tokenSwapManager.createOrder('SUCCESS', '', 10, 10, 2, user, {from: bridge}); 
      await this.tokenSwapManager.createOrder('SUCCESS', '', 10, 10, 2, user, {from: bridge});
      const lockedTokens = await this.tokenSwapManager.getLockedAmount(user, {from: user}); 
      expect(lockedTokens.toNumber()).to.be.equal(30);
    });
    
    it("successfully mint tokens to user address", async function() {
      const balance = await this.inverseToken.balanceOf(user);
      expect(balance.toNumber()).to.be.equal(10);
    });


  });

  describe("#unsuccessfulCreateOrder", function () {
    it("throws error when user is not whitelisted", async function() {
      await expectRevert(
        this.tokenSwapManager.createOrder('SUCCESS', '', 10, 10, 2, user, {from: bridge}),
        "only whitelisted address may place orders"
      );
    });

    it("throws error from trading engine: return user funds", async function() {
      await this.storage.setWhitelistedAddress(user, { from: owner }); 
      await this.stableCoin.mintTokens(this.collateralPool.address, 10, { from: owner });
      await this.tokenSwapManager.createOrder('ERROR', 'error message', 10, 10, 2, user, {from: bridge});
      
      const userReturnedBalance = await this.stableCoin.balanceOf(user);
      expect(userReturnedBalance.toNumber()).to.be.equal(10);    
    });
  });

  describe("#successfulRedemptionOrders", function () {

    beforeEach(async function () {
      await this.storage.setWhitelistedAddress(user, { from: owner }); 
      await this.inverseToken.mintTokens(this.collateralPool.address, 20, { from: owner });
      this.reciept = await this.tokenSwapManager.redeemOrder(
        'SUCCESS',       // Order Type
        '',              // Order Message 
        10,              // Tokens Given
        10,              // Tokens Recieved
        2,               // Avg Blended Fee
        user,            // Whitelisted User 
        { from: bridge } // Sent From Bridge 
      ); 

    });


    it("emits successful order event", async function() {
      expectEvent(this.reciept, "SuccessfulOrder", {
        orderType: "REDEEM",
        whitelistedAddress: user,
        tokensGiven: "10",
        tokensRecieved: "10"
      });
      
    });

    it("locks tokens from creation order", async function() {
      await this.tokenSwapManager.createOrder('SUCCESS', '', 10, 10, 2, user, {from: bridge}); 
      await expectRevert(
        this.tokenSwapManager.redeemOrder('SUCCESS', '', 10, 10, 2, user, {from: bridge}),
        "cannot redeem locked tokens"
      );
    });

    it("locks tokens from multiple creation orders", async function() {
      await this.tokenSwapManager.createOrder('SUCCESS', '', 10, 10, 2, user, {from: bridge}); 
      await this.tokenSwapManager.createOrder('SUCCESS', '', 10, 10, 2, user, {from: bridge}); 
      await this.tokenSwapManager.createOrder('SUCCESS', '', 10, 10, 2, user, {from: bridge}); 
      await expectRevert(
        this.tokenSwapManager.redeemOrder('SUCCESS', '', 30, 30, 2, user, {from: bridge}),
        "cannot redeem locked tokens"
      );
    });

    it("successfully unlock tokens after creation order", async function() {
      await this.tokenSwapManager.createOrder('SUCCESS', '', 10, 10, 2, user, {from: bridge});
      const reciept = await this.tokenSwapManager.redeemOrder('SUCCESS', '', 5, 5, 2, user, {from: bridge});
      expectEvent(reciept, "SuccessfulOrder", {
        orderType: "REDEEM",
        whitelistedAddress: user,
        tokensGiven: "5",
        tokensRecieved: "5"
      });
    });

    it("successfully burn tokens from collateral pool", async function() {
      const balance = await this.inverseToken.balanceOf(this.collateralPool.address);
      expect(balance.toNumber()).to.be.equal(10);
    });

  });

  describe("#unsuccessfulRedemptionOrder", function () {
    it("throws error when user is not whitelisted", async function() {
      await expectRevert(
        this.tokenSwapManager.redeemOrder('SUCCESS', '', 10, 10, 2, user, {from: bridge}),
        "only whitelisted address may place orders"
      );
    });

    it("throws error from trading engine: return user funds", async function() {
      await this.storage.setWhitelistedAddress(user, { from: owner }); 
      await this.inverseToken.mintTokens(this.collateralPool.address, 10, { from: owner });
      await this.tokenSwapManager.redeemOrder('ERROR', 'error message', 10, 10, 2, user, {from: bridge});
      
      const userReturnedBalance = await this.inverseToken.balanceOf(user);
      expect(userReturnedBalance.toNumber()).to.be.equal(10);    
    });
  });
  
  describe("#dailyRebalance", function () {
    const cashPosition = getEth(2*1000 * 1000)
    const balance = getEth(1000)
    const totalTokenSupply = getEth(1)

    beforeEach(async function () {
      await this.inverseToken.mintTokens(owner, totalTokenSupply, {
        from: owner
      });
    });

    it("should keep same values without price change and fee", async function() {
      const price = getEth(1000)
      const lendingFee = getEth(0)
      await this.storage.setAccounting(price, cashPosition, balance, lendingFee, {
        from: owner
      });
      await time.increase(time.duration.days(1));

      await this.tokenSwapManager.dailyRebalance(price, lendingFee, cashPosition, balance, totalTokenSupply, {from: owner});
      const lastActivityDay = await this.storage.lastActivityDay();
      const accounting = await this.storage.getAccounting(lastActivityDay.toNumber());

      expect(new BigNumber((accounting[0])).eq(price)).to.be.true;
      expect(new BigNumber((accounting[1])).eq(cashPosition)).to.be.true;
      expect(new BigNumber((accounting[2])).eq(balance)).to.be.true;
      expect(new BigNumber((accounting[3])).eq(lendingFee)).to.be.true;
    });

    it("should decrease by fee with same price", async function() {
      const price = getEth(1000)
      const lendingFee = getEth(365)
      await this.storage.setAccounting(price, cashPosition, balance, lendingFee, {
        from: owner
      });
      await time.increase(time.duration.days(1));

      const cashPositionMinusFee = "1980000000000000000000000";

      const result = await this.compositionCalculator.calculatePCF(cashPosition, balance, price, lendingFee, 1, getEth(0));
      const endBalance = result[1];
      const endCashPosition = result[2];

      await this.tokenSwapManager.dailyRebalance(price, lendingFee, cashPositionMinusFee, endBalance, totalTokenSupply, {from: owner});
      const lastActivityDay = await this.storage.lastActivityDay();
      const accounting = await this.storage.getAccounting(lastActivityDay.toNumber());

      expect(new BigNumber((accounting[0])).eq(price)).to.be.true;
      expect(new BigNumber((accounting[1])).eq(cashPositionMinusFee)).to.be.true;
      expect(new BigNumber((accounting[2])).eq(endBalance)).to.be.true;
      expect(new BigNumber((accounting[3])).eq(lendingFee)).to.be.true;
    });
    it("should increase when price falls", async function() {
      const price = getEth(900)
      const lendingFee = getEth(365)

      await this.storage.setAccounting(price, cashPosition, balance, lendingFee, {
        from: owner
      });
      await time.increase(time.duration.days(1));

      const result = await this.compositionCalculator.calculatePCF(cashPosition, balance, price, lendingFee, 1, getEth(0));
      const endBalance = result[1];
      const endCashPosition = result[2];

      await this.tokenSwapManager.dailyRebalance(price, lendingFee, endCashPosition, endBalance, totalTokenSupply, {from: owner});
      const lastActivityDay = await this.storage.lastActivityDay();
      const accounting = await this.storage.getAccounting(lastActivityDay.toNumber());

      expect(new BigNumber((accounting[0])).eq(price)).to.be.true;
      expect(new BigNumber((accounting[1])).eq(endCashPosition)).to.be.true;
      expect(new BigNumber((accounting[2])).eq(endBalance)).to.be.true;
      expect(new BigNumber((accounting[3])).eq(lendingFee)).to.be.true;
      const nav = await this.compositionCalculator. getCurrentNAV();
      expect(new BigNumber(nav).gt(getEth(1000*1000))).to.be.true;

    });
    it("should decrease when price falls", async function() {
      const price = getEth(1100)
      const lendingFee = getEth(365)

      await this.storage.setAccounting(price, cashPosition, balance, lendingFee, {
        from: owner
      });
      await time.increase(time.duration.days(1));

      const result = await this.compositionCalculator.calculatePCF(cashPosition, balance, price, lendingFee, 1, getEth(0));
      const endBalance = result[1];
      const endCashPosition = result[2];


      await this.tokenSwapManager.dailyRebalance(price, lendingFee, endCashPosition, endBalance, totalTokenSupply, {from: owner});
      const lastActivityDay = await this.storage.lastActivityDay();
      const accounting = await this.storage.getAccounting(lastActivityDay.toNumber());

      expect(new BigNumber((accounting[0])).eq(price)).to.be.true;
      expect(new BigNumber((accounting[1])).eq(endCashPosition)).to.be.true;
      expect(new BigNumber((accounting[2])).eq(endBalance)).to.be.true;
      expect(new BigNumber((accounting[3])).eq(lendingFee)).to.be.true;
      const nav = await this.compositionCalculator. getCurrentNAV();
      expect(new BigNumber(nav).lt(getEth(1000*1000))).to.be.true;
    });

    it("should throw error when cash positions do not match", async function() {
      const price = getEth(1000)
      const lendingFee = getEth(1)

      await this.storage.setAccounting(price, cashPosition, balance, lendingFee, {
        from: owner
      });
      await time.increase(time.duration.days(1));

      await expectRevert(
         this.tokenSwapManager.dailyRebalance(price, lendingFee, cashPosition, balance, totalTokenSupply, {from: owner}),
        "The cash positions should match."
      );
    });
  });

  describe("#thresholdRebalance", function () {
    const cashPosition = getEth(2*1000 * 1000)
    const balance = getEth(1000)
    const totalTokenSupply = getEth(1)

    beforeEach(async function () {
      await this.inverseToken.mintTokens(owner, totalTokenSupply, {
        from: owner
      });
    });
    it("should keep same values without price change and fee", async function() {
      const price = getEth(1000)
      const lendingFee = getEth(0)
      await this.storage.setAccounting(price, cashPosition, balance, lendingFee, {
        from: owner
      });
      await time.increase(time.duration.days(1));
      await this.tokenSwapManager.thresholdRebalance(price, lendingFee, cashPosition, balance, totalTokenSupply, {from: owner});
      const lastActivityDay = await this.storage.lastActivityDay();
      const accounting = await this.storage.getAccounting(lastActivityDay.toNumber());

      expect(new BigNumber((accounting[0])).eq(price)).to.be.true;
      expect(new BigNumber((accounting[1])).eq(cashPosition)).to.be.true;
      expect(new BigNumber((accounting[2])).eq(balance)).to.be.true;
      expect(new BigNumber((accounting[3])).eq(lendingFee)).to.be.true;
    });
    it("should increase when price falls", async function() {
      const price = getEth(900)
      const lendingFee = getEth(365)

      await this.storage.setAccounting(price, cashPosition, balance, lendingFee, {
        from: owner
      });
      await time.increase(time.duration.days(1));
      const result = await this.compositionCalculator.calculatePCF(cashPosition, balance, price, 0, 1, getEth(0));
      const endBalance = result[1];
      const endCashPosition = result[2];

      await this.tokenSwapManager.thresholdRebalance(price, lendingFee, endCashPosition, endBalance, totalTokenSupply, {from: owner});
      const lastActivityDay = await this.storage.lastActivityDay();
      const accounting = await this.storage.getAccounting(lastActivityDay.toNumber());

      expect(new BigNumber((accounting[0])).eq(price)).to.be.true;
      expect(new BigNumber((accounting[1])).eq(endCashPosition)).to.be.true;
      expect(new BigNumber((accounting[2])).eq(endBalance)).to.be.true;
      expect(new BigNumber((accounting[3])).eq(lendingFee)).to.be.true;
      const nav = await this.compositionCalculator. getCurrentNAV();
      expect(new BigNumber(nav).gt(getEth(1000*1000))).to.be.true;

    });
    it("should decrease when price falls", async function() {
      const price = getEth(1100)
      const lendingFee = getEth(365)

      await this.storage.setAccounting(price, cashPosition, balance, lendingFee, {
        from: owner
      });
      await time.increase(time.duration.days(1));

      const result = await this.compositionCalculator.calculatePCF(cashPosition, balance, price, 0, 1, getEth(0));
      const endBalance = result[1];
      const endCashPosition = result[2];


      await this.tokenSwapManager.thresholdRebalance(price, lendingFee, endCashPosition, endBalance, totalTokenSupply, {from: owner});
      const lastActivityDay = await this.storage.lastActivityDay();
      const accounting = await this.storage.getAccounting(lastActivityDay.toNumber());

      expect(new BigNumber((accounting[0])).eq(price)).to.be.true;
      expect(new BigNumber((accounting[1])).eq(endCashPosition)).to.be.true;
      expect(new BigNumber((accounting[2])).eq(endBalance)).to.be.true;
      expect(new BigNumber((accounting[3])).eq(lendingFee)).to.be.true;
      const nav = await this.compositionCalculator. getCurrentNAV();
      expect(new BigNumber(nav).lt(getEth(1000*1000))).to.be.true;
    });

    it("should throw error when cash positions do not match", async function() {
      const price = getEth(1000)
      const lendingFee = getEth(1)

      await this.storage.setAccounting(price, cashPosition, balance, lendingFee, {
        from: owner
      });
      await time.increase(time.duration.days(1));

      await expectRevert(
         this.tokenSwapManager.thresholdRebalance(price, lendingFee, 100, balance, totalTokenSupply, {from: owner}),
        "The cash positions should match."
      );
    });
  });
  
});