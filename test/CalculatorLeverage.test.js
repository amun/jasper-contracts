const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");
const BigNumber = require("bignumber.js");

const { time, expectRevert, ether, BN } = require("@openzeppelin/test-helpers");

const InverseToken = contract.fromArtifact("InverseToken");
const CalculatorLeverage = contract.fromArtifact("CalculatorLeverage");
const StorageLeverage = contract.fromArtifact("StorageLeverage");

const getNumberWithDecimal = num =>
  new BigNumber(num)
    .div(new BigNumber("10").pow(new BigNumber("18")))
    .toFixed(18);
const getEth = num =>
  new BigNumber(num).times(new BigNumber("10").pow("18")).integerValue();

describe("CalculatorLeverage", function() {
  const [owner] = accounts;
  this.timeout(5000);

  beforeEach(async function() {
    this.storage = await StorageLeverage.new({ from: owner });

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
    }); //0
    this.token = await InverseToken.new({ from: owner });
    await this.token.initialize(
      "InverseToken",
      "IT",
      18,
      this.storage.address,
      owner
    );

    this.contract = await CalculatorLeverage.new({ from: owner });
    await this.contract.initialize(this.storage.address, this.token.address);
  });

  describe("#getTokenAmountCreatedByCash", function() {
    it("Correct Tokens Created From Creation Order", async function() {
      const mintPrice = getEth(1000);
      const tokensGiven = getEth(10);
      const gasFee = getEth(1);

      // (TokensGiven - GasFee - MintingFee) / MintPrice
      const expectedTokensCreated = "8973000000000000";

      const tokenCreated = await this.contract.getTokensCreatedByCash(
        mintPrice,
        tokensGiven,
        gasFee
      );
      expect(tokenCreated.toString()).to.be.equal(expectedTokensCreated);
    });
  });

  describe("#getCashAmountCreatedByToken", function() {
    it("Correct Stablecoin Recieved from Redemption Order", async function() {
      const burnPrice = getEth(1000);
      const timeElapsed = getEth(1);
      const tokensGiven = getEth(10);
      const gasFee = getEth(1);

      // (TokensGiven * BurnPrice) - GasFee - MintingFee - ManagementFee
      const expectedTokensCreated = "9968878387462500000000";

      const tokenCreated = await this.contract.getCashCreatedByTokens(
        burnPrice,
        timeElapsed,
        tokensGiven,
        gasFee
      );
      expect(tokenCreated.toString()).to.be.equal(expectedTokensCreated);
    });
  });
});
