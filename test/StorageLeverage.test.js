const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");
const BigNumber = require("bignumber.js");

const {
  expectEvent,
  expectRevert,
  time,
  ether,
  BN,
} = require("@openzeppelin/test-helpers");

const StorageLeverage = contract.fromArtifact("StorageLeverage");

const getDateForBlockTime = async () => {
  const latestBlockTime = await time.latest();
  const latestBlockTimestamp = latestBlockTime.toNumber() * 1000;

  const dateObj = new Date(latestBlockTimestamp);
  const month = dateObj.getUTCMonth() + 1; //months from 1-12
  const day = dateObj.getUTCDate();
  const year = dateObj.getUTCFullYear();

  return year * 10000 + month * 100 + day;
};
describe("PersistentStorage", function() {
  const [owner, notOwner, notListed, bridge] = accounts;
  const managementFee = ether("7");
  const minRebalanceAmount = ether("1");
  const lastMintingFee = ether("0.001");
  const balancePrecision = 12;
  const minimumMintingFee = ether("5");
  const minimumTrade = ether("50");
  beforeEach(async function() {
    this.contract = await StorageLeverage.new({ from: owner });
    await this.contract.initialize(
      owner,
      managementFee,
      minRebalanceAmount,
      balancePrecision,
      lastMintingFee,
      minimumMintingFee,
      minimumTrade
    );

    await this.contract.setBridge(bridge, { from: owner });
  });

  describe("#getMintingFee", function() {
    it("gets minting fee", async function() {
      const expectedTotalFee = ether("0.001");
      const cash = ether("49000");

      const resultMintingFee = await this.contract.getMintingFee(cash, {
        from: notListed,
      });
      expect(resultMintingFee).to.be.bignumber.equal(expectedTotalFee);
    });
  });
});
