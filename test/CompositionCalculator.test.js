const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");
const BigNumber = require("bignumber.js");

const { time, expectRevert, ether, BN } = require("@openzeppelin/test-helpers");

const InverseToken = contract.fromArtifact("InverseToken");
const CompositionCalculator = contract.fromArtifact("CompositionCalculator");
const PersistentStorage = contract.fromArtifact("PersistentStorage");

const getNumberWithDecimal = num =>
  new BigNumber(num)
    .div(new BigNumber("10").pow(new BigNumber("18")))
    .toFixed(18);
const getEth = num =>
  new BigNumber(num).times(new BigNumber("10").pow("18")).integerValue();

const percentageMinusCreationRedemptionFee = 0.997;

describe("CompositionCalculator", function() {
  const [owner] = accounts;
  this.timeout(5000);

  beforeEach(async function() {
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
    }); //0
    this.token = await InverseToken.new({ from: owner });
    await this.token.initialize(
      "InverseToken",
      "IT",
      18,
      this.storage.address,
      owner
    );

    this.contract = await CompositionCalculator.new({ from: owner });
    await this.contract.initialize(this.storage.address, this.token.address);
  });

  describe("#getNetTokenValue", function() {
    it("does match expected value", async function() {
      const cashPosition = getEth(200000);
      const balance = getEth(100);
      const price = getEth(1000);
      const expectedNetTokenValue = getEth(100000);

      const netTokenValue = await this.contract.getNetTokenValue(
        cashPosition,
        balance,
        price
      );

      expect(getNumberWithDecimal(expectedNetTokenValue)).to.be.equal(
        getNumberWithDecimal(netTokenValue)
      );
    });
  });

  describe("#getLendingFeeInCrypto", function() {
    it("does match expected value", async function() {
      const lendingFee = getEth(2.5);
      const balance = getEth(100);
      const daysSinceLastRebalance = 1;

      const cryptoForLendingFee = await this.contract.getLendingFeeInCrypto(
        lendingFee,
        balance,
        daysSinceLastRebalance
      );

      const expectedResult = new BigNumber(2.5)
        .div(100)
        .div(365)
        .times(1)
        .times(100)
        .toFixed(16);

      //is only same to 16th decimal?? Is this because of floating point error?
      expect(expectedResult).to.be.equal(
        new BigNumber(getNumberWithDecimal(cryptoForLendingFee)).toFixed(16)
      );
    });
  });

  describe("#getNeededChangeInBalanceToRebalance", function() {
    it("does match expected positive change", async function() {
      const netTokenValue = getEth(110000);
      const balance = getEth(100);
      const price = getEth(900);
      const expectedChange = "22.222222222222222222";

      const result = await this.contract.getNeededChangeInBalanceToRebalance(
        netTokenValue,
        balance,
        price
      );
      const [change, isNegative] = Object.values(result);

      expect(expectedChange).to.be.equal(getNumberWithDecimal(change));
      expect(isNegative).to.be.equal(false);
    });

    it("does match expected negative change", async function() {
      const netTokenValue = getEth(90000);
      const balance = getEth(100);
      const price = getEth(1100);
      const expectedChange = "18.181818181818181818";

      const result = await this.contract.getNeededChangeInBalanceToRebalance(
        netTokenValue,
        balance,
        price
      );
      const [change, isNegative] = Object.values(result);

      expect(expectedChange).to.be.equal(getNumberWithDecimal(change));
      expect(isNegative).to.be.equal(true);
    });
  });
  describe("#calculateDailyPCF", function() {
    it("does not change when price stays and fee is zero", async function() {
      const balance = getEth(100);
      const cashPosition = getEth(200000);
      const price = getEth(1000);
      const lendingFee = getEth(0);
      const totalTokenSupply = getEth(1);

      await this.token.mintTokens(owner, totalTokenSupply, {
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

      const result = await this.contract.calculateDailyPCF(price, lendingFee, {
        from: owner
      });
      const [
        endNetTokenValue,
        endBalance,
        endCashPosition,
        feeInFiat,
        changeInBalance,
        isChangeInBalanceNeg,
        cashFromCryptoSale
      ] = Object.values(result);

      expect(changeInBalance.toNumber()).to.be.equal(0);
      expect(new BigNumber(getNumberWithDecimal(endNetTokenValue)).eq(100000))
        .to.be.true;
    });
  });

  describe("#calculatePCF", function() {
    it("does not change changeInBalance when smaller then minRebalanceAmount", async function() {
      const balance = getEth(100);
      const cashPosition = getEth(200000);
      const price = getEth(1000);
      const lendingFee = getEth(2.5);
      const daysSinceLastRebalance = 1;
      const minRebalanceAmount = getEth(1);
      const precision = "0";

      const result = await this.contract.calculatePCF(
        cashPosition,
        balance,
        price,
        lendingFee,
        daysSinceLastRebalance,
        minRebalanceAmount,
        precision
      );

      const [
        endNetTokenValue,
        endBalance,
        endCashPosition,
        feeInFiat,
        changeInBalance,
        isChangeInBalanceNeg,
        cashFromCryptoSale
      ] = Object.values(result);

      expect(changeInBalance.toNumber()).to.be.equal(0);
      //netTokenValue should get smaller because of fee
      expect(new BigNumber(getNumberWithDecimal(endNetTokenValue)).lt(100000))
        .to.be.true;
    });
    it("does change positive when smaller price", async function() {
      const balance = getEth(100);
      const cashPosition = getEth(200000);
      const price = getEth(900);
      const lendingFee = getEth(2.5);
      const daysSinceLastRebalance = 1;
      const minRebalanceAmount = getEth(1);
      const precision = "0";

      const result = await this.contract.calculatePCF(
        cashPosition,
        balance,
        price,
        lendingFee,
        daysSinceLastRebalance,
        minRebalanceAmount,
        precision
      );
      const [
        endNetTokenValue,
        endBalance,
        endCashPosition,
        feeInFiat,
        changeInBalance,
        isChangeInBalanceNeg
      ] = Object.values(result);

      expect(getNumberWithDecimal(changeInBalance)).to.be.equal(
        "22.215372907153729022"
      );
      expect(getNumberWithDecimal(feeInFiat)).to.be.equal(
        "6.164383561643880000"
      );
      expect(new BigNumber(getNumberWithDecimal(endNetTokenValue)).gt(100000))
        .to.be.true;
      expect(new BigNumber(endBalance).gt(balance)).to.be.true;
      expect(new BigNumber(endCashPosition).gt(cashPosition)).to.be.true;
      expect(isChangeInBalanceNeg).to.be.false;
    });
    it("does floor changeInBalance to 8 decimals", async function() {
      const balance = getEth(100);
      const cashPosition = getEth(200000);
      const price = getEth(900);
      const lendingFee = getEth(2.5);
      const daysSinceLastRebalance = 1;
      const minRebalanceAmount = getEth(1);
      const precision = "10";

      const result = await this.contract.calculatePCF(
        cashPosition,
        balance,
        price,
        lendingFee,
        daysSinceLastRebalance,
        minRebalanceAmount,
        precision
      );
      const [
        endNetTokenValue,
        endBalance,
        endCashPosition,
        feeInFiat,
        changeInBalance,
        isChangeInBalanceNeg
      ] = Object.values(result);

      expect(getNumberWithDecimal(changeInBalance)).to.be.equal(
        "22.215372900000000000"
      );
      expect(getNumberWithDecimal(feeInFiat)).to.be.equal(
        "6.164383561643880000"
      );
      expect(new BigNumber(getNumberWithDecimal(endNetTokenValue)).gt(100000))
        .to.be.true;
      expect(new BigNumber(endBalance).gt(balance)).to.be.true;
      expect(new BigNumber(endCashPosition).gt(cashPosition)).to.be.true;
      expect(isChangeInBalanceNeg).to.be.false;
    });
    it("does change positive when increased price", async function() {
      const balance = getEth(100);
      const cashPosition = getEth(200000);
      const price = getEth(1100);
      const lendingFee = getEth(2.5);
      const daysSinceLastRebalance = 1;
      const minRebalanceAmount = getEth(1);
      const precision = "0";

      const result = await this.contract.calculatePCF(
        cashPosition,
        balance,
        price,
        lendingFee,
        daysSinceLastRebalance,
        minRebalanceAmount,
        precision
      );
      const [
        endNetTokenValue,
        endBalance,
        endCashPosition,
        feeInFiat,
        changeInBalance,
        isChangeInBalanceNeg
      ] = Object.values(result);

      expect(getNumberWithDecimal(changeInBalance)).to.be.equal(
        "18.188667496886675018"
      );
      expect(getNumberWithDecimal(feeInFiat)).to.be.equal(
        "7.534246575342520000"
      );
      expect(new BigNumber(getNumberWithDecimal(endNetTokenValue)).lt(100000))
        .to.be.true;
      expect(new BigNumber(endBalance).lt(balance)).to.be.true;
      expect(new BigNumber(endCashPosition).lt(cashPosition)).to.be.true;
      expect(isChangeInBalanceNeg).to.be.true;
    });
  });

  describe("#getTokenAmountCreatedByCash", function() {
    it("does give correct token amount for unbalanced product with lower spot price.", async function() {
      //2000+1*900 = (1200 + 800)-1*800
      const balance = getEth(1);
      const cashPosition = getEth(2000);
      const totalTokenSupply = getEth(1);

      const cash = getEth(1200);
      const spot = getEth(800);

      const tokenCreated = await this.contract.getTokenAmountCreatedByCash(
        cashPosition,
        balance,
        totalTokenSupply,
        cash,
        spot
      );
      expect(getNumberWithDecimal(tokenCreated)).to.be.equal(
        getNumberWithDecimal(totalTokenSupply)
      );
    });

    it("does give correct token amount for rebalanced product with lower spot price.", async function() {
      //2000 - 1 * 1000 = (1100 + 900) - 1 * 1000
      const balance = getEth(1);
      const cashPosition = getEth(2000);
      const totalTokenSupply = getEth(1);

      const cash = getEth(1100);
      const spot = getEth(900);

      const tokenCreated = await this.contract.getTokenAmountCreatedByCash(
        cashPosition,
        balance,
        totalTokenSupply,
        cash,
        spot
      );
      expect(getNumberWithDecimal(tokenCreated)).to.be.equal(
        getNumberWithDecimal(totalTokenSupply)
      );
    });

    it("does give correct token amount for rebalanced product with higher spot price.", async function() {
      //2000 - 1 * 1000 = (900 + 1100) - 1 * 1000
      const balance = getEth(1);
      const cashPosition = getEth(2000);
      const totalTokenSupply = getEth(1);

      const cash = getEth(900);
      const spot = getEth(1100);

      const tokenCreated = await this.contract.getTokenAmountCreatedByCash(
        cashPosition,
        balance,
        totalTokenSupply,
        cash,
        spot
      );
      expect(getNumberWithDecimal(tokenCreated)).to.be.equal(
        getNumberWithDecimal(totalTokenSupply)
      );
    });
    it("does give correct token amount for unbalanced product with higher spot price.", async function() {
      //2000+1*900 = (900 + 1100)-1*900
      const balance = getEth(1);
      const cashPosition = getEth(2000);
      const totalTokenSupply = getEth(1);

      const cash = getEth(900);
      const spot = getEth(1100);

      const tokenCreated = await this.contract.getTokenAmountCreatedByCash(
        cashPosition,
        balance,
        totalTokenSupply,
        cash,
        spot
      );
      expect(getNumberWithDecimal(tokenCreated)).to.be.equal(
        getNumberWithDecimal(totalTokenSupply)
      );
    });

    it("does give correct token amount for unbalanced product with same spot price.", async function() {
      //2000+1*900 = (1100 + 900)-1*900
      const balance = getEth(1);
      const cashPosition = getEth(2000);
      const totalTokenSupply = getEth(1);

      const cash = getEth(2200);
      const spot = getEth(900);

      const tokenCreated = await this.contract.getTokenAmountCreatedByCash(
        cashPosition,
        balance,
        totalTokenSupply,
        cash,
        spot
      );
      expect(getNumberWithDecimal(tokenCreated)).to.be.equal(
        getNumberWithDecimal(getEth(2))
      );
    });

    it("does give correct token amount for rebalanced product with same spot price.", async function() {
      //2000+1*1000 = (1000 + 1000)-1*1000
      const balance = getEth(1);
      const cashPosition = getEth(2000);
      const totalTokenSupply = getEth(1);

      const cash = getEth(2000);
      const spot = getEth(1000);

      const tokenCreated = await this.contract.getTokenAmountCreatedByCash(
        cashPosition,
        balance,
        totalTokenSupply,
        cash,
        spot
      );
      expect(getNumberWithDecimal(tokenCreated)).to.be.equal(
        getNumberWithDecimal(getEth(2))
      );
    });
  });

  describe("#getCashAmountCreatedByToken", function() {
    it("does give correct cash payed for lower spot price.", async function() {
      //2000-1*800 = 1200
      const balance = getEth(1);
      const cashPosition = getEth(2000);
      const totalTokenSupply = getEth(1);

      const tokenAmount = getEth(1);
      const spot = getEth(800);

      const cashFromTokenRedeem = await this.contract.getCashAmountCreatedByToken(
        cashPosition,
        balance,
        totalTokenSupply,
        tokenAmount,
        spot
      );

      expect(getNumberWithDecimal(cashFromTokenRedeem)).to.be.equal(
        getNumberWithDecimal(cashPosition - spot)
      );
    });
    it("does give correct cash payed for higher spot price.", async function() {
      //2000-1*1200 = 800
      const balance = getEth(1);
      const cashPosition = getEth(2000);
      const totalTokenSupply = getEth(1);

      const tokenAmount = getEth(1);
      const spot = getEth(1200);

      const cashFromTokenRedeem = await this.contract.getCashAmountCreatedByToken(
        cashPosition,
        balance,
        totalTokenSupply,
        tokenAmount,
        spot
      );

      expect(getNumberWithDecimal(cashFromTokenRedeem)).to.be.equal(
        getNumberWithDecimal(cashPosition - spot)
      );
    });

    it("does give correct cash payed for balanced spot price.", async function() {
      //2000-1*1000 = 1000
      const balance = getEth(1);
      const cashPosition = getEth(2000);
      const totalTokenSupply = getEth(1);

      const tokenAmount = getEth(1);
      const spot = getEth(1000);

      const cashFromTokenRedeem = await this.contract.getCashAmountCreatedByToken(
        cashPosition,
        balance,
        totalTokenSupply,
        tokenAmount,
        spot
      );

      expect(getNumberWithDecimal(cashFromTokenRedeem)).to.be.equal(
        getNumberWithDecimal(cashPosition - spot)
      );
    });
  });
  describe("#getCurrentNetTokenValue", function() {
    it("Should match netTokenValue.", async function() {
      const cashPosition = getEth(2 * 1000);
      const balance = getEth(1);
      const price = getEth(1000);
      const fee = getEth(0);
      await this.token.mintTokens(owner, getEth(1), {
        from: owner
      });
      await this.storage.setAccounting(price, cashPosition, balance, fee, {
        from: owner
      });

      const result = await this.contract.getCurrentNetTokenValue();
      expect(result.toString()).to.be.equal(getEth(1000).toFixed());
    });
    it("Should fail when cash position is small then balance.", async function() {
      const cashPosition = getEth(900);
      const balance = getEth(1);
      const price = getEth(1000);
      const fee = getEth(0);
      await this.token.mintTokens(owner, getEth(1), {
        from: owner
      });
      await this.storage.setAccounting(price, cashPosition, balance, fee, {
        from: owner
      });
      await expectRevert(
        this.contract.getCurrentNetTokenValue(),
        "The cash position needs to be bigger then the borrowed crypto is worth"
      );
    });
  });

  describe("#getCurrentTokenAmountCreatedByCash", function() {
    const fee = getEth(0);
    const totalTokenSupply = getEth(1);
    const price = getEth(1000);

    beforeEach(async function() {
      await this.token.mintTokens(owner, getEth(1), {
        from: owner
      });
    });
    it("does give correct token amount for unbalanced product with lower spot price.", async function() {
      //2000+1*900 = (1200 + 800)-1*800
      const balance = getEth(1);
      const cashPosition = getEth(2000);

      await this.storage.setAccounting(price, cashPosition, balance, fee, {
        from: owner
      });
      const cash = getEth(2400);
      const spot = getEth(800);

      const tokenCreated = await this.contract.getCurrentTokenAmountCreatedByCash(
        cash,
        spot,
        0
      );
      expect(getNumberWithDecimal(tokenCreated)).to.be.equal(
        getNumberWithDecimal(
          totalTokenSupply.times(2).times(percentageMinusCreationRedemptionFee)
        )
      );
    });
    it("does give correct token amount for unbalanced product with lower spot price.", async function() {
      //2000+1*900 = (1200 + 800)-1*800
      const balance = getEth(1);
      const cashPosition = getEth(2000);

      await this.storage.setAccounting(price, cashPosition, balance, fee, {
        from: owner
      });
      const cash = getEth(1205);
      const spot = getEth(800);

      const tokenCreated = await this.contract.getCurrentTokenAmountCreatedByCash(
        cash,
        spot,
        0
      );
      expect(getNumberWithDecimal(tokenCreated)).to.be.equal(
        getNumberWithDecimal(totalTokenSupply)
      );
    });
    it("does give correct token amount for rebalanced product with lower spot price.", async function() {
      //2000 - 1 * 1000 = (1100 + 900) - 1 * 1000
      const balance = getEth(1);
      const cashPosition = getEth(2000);

      const cash = getEth(2200);
      const spot = getEth(900);
      await this.storage.setAccounting(price, cashPosition, balance, fee, {
        from: owner
      });

      const tokenCreated = await this.contract.getCurrentTokenAmountCreatedByCash(
        cash,
        spot,
        0
      );
      expect(getNumberWithDecimal(tokenCreated)).to.be.equal(
        getNumberWithDecimal(
          totalTokenSupply.times(2).times(percentageMinusCreationRedemptionFee)
        )
      );
    });

    it("does give correct token amount for rebalanced product with higher spot price.", async function() {
      //2000 - 1 * 1000 = (900 + 1100) - 1 * 1000
      const balance = getEth(1);
      const cashPosition = getEth(2000);
      const totalTokenSupply = getEth(1);

      const cash = getEth(1800);
      const spot = getEth(1100);
      await this.storage.setAccounting(price, cashPosition, balance, fee, {
        from: owner
      });

      const tokenCreated = await this.contract.getCurrentTokenAmountCreatedByCash(
        cash,
        spot,
        0
      );
      expect(getNumberWithDecimal(tokenCreated)).to.be.equal(
        getNumberWithDecimal(
          totalTokenSupply.times(2).times(percentageMinusCreationRedemptionFee)
        )
      );
    });
    it("does give correct token amount for unbalanced product with higher spot price.", async function() {
      //2000+1*900 = (900 + 1100)-1*900
      const balance = getEth(1);
      const cashPosition = getEth(2000);
      const totalTokenSupply = getEth(1);

      const cash = getEth(1800);
      const spot = getEth(1100);
      await this.storage.setAccounting(price, cashPosition, balance, fee, {
        from: owner
      });

      const tokenCreated = await this.contract.getCurrentTokenAmountCreatedByCash(
        cash,
        spot,
        0
      );
      expect(getNumberWithDecimal(tokenCreated)).to.be.equal(
        getNumberWithDecimal(
          totalTokenSupply.times(2).times(percentageMinusCreationRedemptionFee)
        )
      );
    });

    it("does give correct token amount for unbalanced product with same spot price.", async function() {
      //2000+1*900 = (1100 + 900)-1*900
      const balance = getEth(1);
      const cashPosition = getEth(2000);
      const totalTokenSupply = getEth(1);

      const cash = getEth(2200);
      const spot = getEth(900);
      await this.storage.setAccounting(price, cashPosition, balance, fee, {
        from: owner
      });

      const tokenCreated = await this.contract.getCurrentTokenAmountCreatedByCash(
        cash,
        spot,
        0
      );
      expect(getNumberWithDecimal(tokenCreated)).to.be.equal(
        getNumberWithDecimal(
          getEth(2).times(percentageMinusCreationRedemptionFee)
        )
      );
    });

    it("does give correct token amount for rebalanced product with same spot price.", async function() {
      //2000+1*1000 = (1000 + 1000)-1*1000
      const balance = getEth(1);
      const cashPosition = getEth(2000);
      const totalTokenSupply = getEth(1);

      const cash = getEth(2000);
      const spot = getEth(1000);
      await this.storage.setAccounting(price, cashPosition, balance, fee, {
        from: owner
      });

      const tokenCreated = await this.contract.getCurrentTokenAmountCreatedByCash(
        cash,
        spot,
        0
      );
      expect(getNumberWithDecimal(tokenCreated)).to.be.equal(
        getNumberWithDecimal(
          getEth(2).times(percentageMinusCreationRedemptionFee)
        )
      );
    });
  });
  describe("#getCurrentCashAmountCreatedByToken", function() {
    const fee = getEth(0);
    const price = getEth(1000);

    beforeEach(async function() {
      await this.token.mintTokens(owner, getEth(1), {
        from: owner
      });
    });
    it("does give correct cash payed for lower spot price.", async function() {
      //2000-1*800 = 1200
      const balance = getEth(1);
      const cashPosition = getEth(2000);

      const tokenAmount = getEth(1);
      const spot = getEth(800);
      await this.storage.setAccounting(price, cashPosition, balance, fee, {
        from: owner
      });

      const cashFromTokenRedeem = await this.contract.getCurrentCashAmountCreatedByToken(
        tokenAmount,
        spot,
        0
      );

      expect(getNumberWithDecimal(cashFromTokenRedeem)).to.be.equal(
        getNumberWithDecimal(
          new BigNumber(cashPosition - spot).minus(getEth(5))
        )
      );
    });
    it("does give correct cash payed for higher spot price.", async function() {
      //2000-1*1200 = 800
      const balance = getEth(1);
      const cashPosition = getEth(2000);

      const tokenAmount = getEth(1);
      const spot = getEth(1200);
      await this.storage.setAccounting(price, cashPosition, balance, fee, {
        from: owner
      });

      const cashFromTokenRedeem = await this.contract.getCurrentCashAmountCreatedByToken(
        tokenAmount,
        spot,
        0
      );

      expect(getNumberWithDecimal(cashFromTokenRedeem)).to.be.equal(
        getNumberWithDecimal(
          new BigNumber(cashPosition - spot).minus(getEth(5))
        )
      );
    });

    it("does give correct cash payed for balanced spot price.", async function() {
      //2000-1*1000 = 1000
      const balance = getEth(1);
      const cashPosition = getEth(2000);

      const tokenAmount = getEth(1);
      const spot = getEth(1000);
      await this.storage.setAccounting(price, cashPosition, balance, fee, {
        from: owner
      });

      const cashFromTokenRedeem = await this.contract.getCurrentCashAmountCreatedByToken(
        tokenAmount,
        spot,
        0
      );

      expect(getNumberWithDecimal(cashFromTokenRedeem)).to.be.equal(
        getNumberWithDecimal(
          new BigNumber(cashPosition - spot).minus(getEth(5))
        )
      );
    });
  });
  describe("#getDaysSinceLastRebalance", function() {
    it("Should return 0 after zero days.", async function() {
      await this.storage.setAccounting(1, 2, 3, 4, { from: owner });
      const result = await this.contract.getDaysSinceLastRebalance();
      expect(result.toString()).to.be.equal("0");
    });
    it("Should return 1 after one day.", async function() {
      await this.storage.setAccounting(1, 2, 3, 4, { from: owner });
      await time.increase(time.duration.days(1));
      const result = await this.contract.getDaysSinceLastRebalance();
      expect(result.toString()).to.be.equal("1");
    });
    it("Should return 28 after 28 days have past.", async function() {
      await this.storage.setAccounting(1, 2, 3, 4, { from: owner });
      await time.increase(time.duration.days(28));
      const result = await this.contract.getDaysSinceLastRebalance();
      expect(result.toString()).to.be.equal("28");
    });
  });
  describe("#getTotalBalance", function() {
    it("Should return total balance.", async function() {
      const balancePerTokenUnit = "3";
      await this.storage.setAccounting(1, 2, balancePerTokenUnit, 4, {
        from: owner
      });
      await this.token.mintTokens(owner, getEth(1), {
        from: owner
      });
      const result = await this.contract.getTotalBalance();
      expect(result.toString()).to.be.equal(balancePerTokenUnit);
    });
  });
  describe("#getTotalCashPosition", function() {
    it("Should return total cash position.", async function() {
      const cashPositionPerTokenUnit = getEth(4).toFixed();
      await this.storage.setAccounting(1, cashPositionPerTokenUnit, 3, 4, {
        from: owner
      });
      await this.token.mintTokens(owner, getEth(1), {
        from: owner
      });
      const result = await this.contract.getTotalCashPosition();
      expect(result.toString()).to.be.equal(cashPositionPerTokenUnit);
    });
  });
  describe("#removeCurrentMintingFeeFromCash", function() {
    it("Should remove minimumMintingFee when bigger then creationFee.", async function() {
      const cash = getEth(10);
      const resultingCash = getEth(5);
      const cashPositionPerTokenUnit = getEth(4).toFixed();
      await this.storage.setAccounting(1, cashPositionPerTokenUnit, 3, 4, {
        from: owner
      });
      await this.token.mintTokens(owner, getEth(1), {
        from: owner
      });

      const result = await this.contract.removeCurrentMintingFeeFromCash(cash);
      expect(result).to.be.bignumber.equal(String(resultingCash));
    });
    it("Should remove creationFee when bigger then minimumMintingFee.", async function() {
      const cash = getEth(10000);
      const resultingCash = ether(new BigNumber(10000).times(0.997).toString());
      const cashPositionPerTokenUnit = getEth(4).toFixed();
      await this.storage.setAccounting(1, cashPositionPerTokenUnit, 3, 4, {
        from: owner
      });
      await this.token.mintTokens(owner, getEth(1), {
        from: owner
      });

      const result = await this.contract.removeCurrentMintingFeeFromCash(cash);
      expect(result).to.be.bignumber.equal(new BN(resultingCash));
    });
  });
  describe("#removeMintingFeeFromCash", function() {
    it("Should remove minimumMintingFee when bigger then creationFee.", async function() {
      const cash = getEth(10);
      const creationFee = getEth(0.001);
      const minimumMintingFee = getEth(5);
      const cashPositionPerTokenUnit = getEth(4).toFixed();
      await this.storage.setAccounting(1, cashPositionPerTokenUnit, 3, 4, {
        from: owner
      });
      await this.token.mintTokens(owner, getEth(1), {
        from: owner
      });

      const result = await this.contract.removeMintingFeeFromCash(
        cash,
        creationFee,
        minimumMintingFee
      );
      expect(result).to.be.bignumber.equal(String(getEth(5)));
    });
    it("Should remove creationFee when bigger then minimumMintingFee.", async function() {
      const cash = getEth(10000);
      const creationFee = getEth(0.003);
      const minimumMintingFee = getEth(5);
      const cashPositionPerTokenUnit = getEth(4).toFixed();
      const resultingCash = ether(new BigNumber(10000).times(0.997).toString());

      await this.storage.setAccounting(1, cashPositionPerTokenUnit, 3, 4, {
        from: owner
      });
      await this.token.mintTokens(owner, getEth(1), {
        from: owner
      });

      const result = await this.contract.removeMintingFeeFromCash(
        cash,
        creationFee,
        minimumMintingFee
      );
      expect(result).to.be.bignumber.equal(String(resultingCash));
    });
  });
});
