const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");

const { expectEvent, expectRevert, time, ether } = require("@openzeppelin/test-helpers");

const PersistentStorage = contract.fromArtifact("PersistentStorage");

const getDateForBlockTime = async () => {
  const latestBlockTime = await time.latest();
  const latestBlockTimestamp = latestBlockTime.toNumber() * 1000;

  const dateObj = new Date(latestBlockTimestamp);
  const month = dateObj.getUTCMonth() + 1; //months from 1-12
  const day = dateObj.getUTCDate();
  const year = dateObj.getUTCFullYear();

  return year * 10000 + month * 100 + day;
};
describe("PersistentStorage", function () {
  const [owner, notOwner, notListed] = accounts;
  const managementFee = ether("7");
  const minRebalanceAmount = ether("1");
  beforeEach(async function () {
    this.contract = await PersistentStorage.new({ from: owner });
    await this.contract.initialize(owner, managementFee, minRebalanceAmount);
  });

  describe("#setWhitelistedAddress", function () {
    it("does not allow a non owner to add a whitelisted address", async function () {
      await expectRevert(
        this.contract.setWhitelistedAddress(notOwner, { from: notOwner }),
        "Ownable: caller is not the owner"
      );
    });

    it("does not allow empty address to be whitelisted", async function () {
      await expectRevert(
        this.contract.setWhitelistedAddress(
          "0x0000000000000000000000000000000000000000",
          { from: owner }
        ),
        "adddress must not be empty"
      );
    });

    it("adds whitelisted address", async function () {
      await this.contract.setWhitelistedAddress(notOwner, { from: owner });

      const isAddressAdded = await this.contract.whitelistedAddresses(notOwner);
      expect(isAddressAdded).to.be.true;
    });
  });

  describe("#removeWhitelistedAddress", function () {
    beforeEach(async function () {
      await this.contract.setWhitelistedAddress(notOwner, { from: owner });
    });

    it("prohibits a non owner from removing whitelisted user", async function () {
      await expectRevert(
        this.contract.removeWhitelistedAddress(notOwner, {
          from: notOwner
        }),
        "Ownable: caller is not the owner"
      );
    });

    it("does not allow an address to be removed which has not been added", async function () {
      await expectRevert(
        this.contract.removeWhitelistedAddress(notListed, { from: owner }),
        "address must be added to be removed allowed"
      );
    });

    it("removes the whitelisted user", async function () {
      await this.contract.removeWhitelistedAddress(notOwner, {
        from: owner
      });

      const isAddressAdded = await this.contract.whitelistedAddresses(notOwner);
      expect(isAddressAdded).to.be.false;
    });
  });

  describe("#updateWhitelistedAddress", function () {
    beforeEach(async function () {
      await this.contract.setWhitelistedAddress(notOwner, { from: owner });
    });

    it("prohibits a non owner from updating whitelisted address", async function () {
      await expectRevert(
        this.contract.updateWhitelistedAddress(notOwner, notListed, {
          from: notOwner
        }),
        "Ownable: caller is not the owner"
      );
    });

    it("updates an whitelisted user", async function () {
      await this.contract.updateWhitelistedAddress(notOwner, notListed, {
        from: owner
      });

      const isAddressAdded = await this.contract.whitelistedAddresses(
        notListed
      );
      expect(isAddressAdded).to.be.true;
      const isAddressAdded2 = await this.contract.whitelistedAddresses(
        notOwner
      );
      expect(isAddressAdded2).to.be.false;
    });
  });

  describe("Accounting getter and setter", function () {
    it("doesn't allow a non owner to set Accounting", async function () {
      await expectRevert(
        this.contract.setAccounting(1, 2, 3, 4, {
          from: notOwner
        }),
        "caller is not the owner or token swap manager"
      );
    });

    it("adds Accounting values and to same date", async function () {
      await this.contract.setAccounting(1, 2, 3, 4, {
        from: owner
      });

      let result = await this.contract.getAccounting(await getDateForBlockTime());
      for (let index = 0; index < Object.keys(result).length; index++) {
        expect(result[index]).to.be.bignumber.equal(String(index + 1));
      }
      // add
      await this.contract.setAccounting(6, 7, 8, 9, {
        from: owner
      });
      result = await this.contract.getAccounting(await getDateForBlockTime());

      for (let index = 0; index < Object.keys(result).length; index++) {
        expect(result[index]).to.be.bignumber.equal(String(index + 6));
      }
    });

    it("sets last activity date variable", async function () {

      await this.contract.setAccounting(1, 2, 3, 4, {
        from: owner
      });

      const resultLastActivityDay = await this.contract.lastActivityDay();

      expect(resultLastActivityDay.toNumber()).to.be.equal(await getDateForBlockTime());
    });

    it("emits AccountingValuesSet", async function () {
      const receipt = await this.contract.setAccounting(1, 2, 3, 4, {
        from: owner
      });

      expectEvent(receipt, "AccountingValuesSet", {
        today: (await getDateForBlockTime()).toString()
      });
    });

    it("setAccountingForLastActivityDay does not update lastActivityDay", async function () {

      await this.contract.setAccounting(1, 2, 3, 4, {
        from: owner
      });
      const blockTimeBefore = await getDateForBlockTime()

      await time.increase(time.duration.days(1));
      const blockTimeAfter = await getDateForBlockTime()

      await this.contract.setAccountingForLastActivityDay(1, 2, 3, 4, {
        from: owner
      });
      const resultLastActivityDayBefore = await this.contract.lastActivityDay();
      await getDateForBlockTime()
      await this.contract.setAccounting(1, 2, 3, 4, {
        from: owner
      });
      const resultLastActivityDayAfter = await this.contract.lastActivityDay();
      expect(resultLastActivityDayBefore.toNumber()).to.be.equal(blockTimeBefore);

      expect(resultLastActivityDayAfter.toNumber()).to.be.equal(blockTimeAfter);
    });

  });

  describe("#setMinRebalanceAmount", function () {
    it("does not allow a non owner to set rebalance information", async function () {
      await expectRevert(
        this.contract.setMinRebalanceAmount(13, { from: notOwner }),
        "Ownable: caller is not the owner"
      );
    });

    it("sets rebalance information", async function () {
      await this.contract.setMinRebalanceAmount(13, { from: owner });

      const resultMinRebalanceAmount = await this.contract.minRebalanceAmount();

      expect(resultMinRebalanceAmount).to.be.bignumber.equal("13");
    });

    it("emits RebalanceValuesSet", async function () {
      const receipt = await this.contract.setMinRebalanceAmount(13, {
        from: owner
      });

      expectEvent(receipt, "RebalanceValuesSet", {
        newMinRebalanceAmount: "13"
      });
    });
  });

  describe("single accounting getters", function () {
    let price = 1,
      cashPosition = 2,
      balance = 3,
      lendingFee = 4;

    beforeEach(async function () {
      await this.contract.setAccounting(
        price,
        cashPosition,
        balance,
        lendingFee,
        {
          from: owner
        }
      );
    });

    it("gets price", async function () {
      const resultPrice = await this.contract.getPrice({
        from: notListed
      });
      expect(resultPrice).to.be.bignumber.equal(price.toString());
    });

    it("gets cashPosition per token", async function () {
      const resultCashPosition = await this.contract.getCashPositionPerToken({
        from: notListed
      });
      expect(resultCashPosition).to.be.bignumber.equal(cashPosition.toString());
    });

    it("gets balance per token", async function () {
      const resultBalance = await this.contract.getBalancePerToken({
        from: notListed
      });
      expect(resultBalance).to.be.bignumber.equal(balance.toString());
    });

    it("gets lendingFee", async function () {
      const resultLendingFee = await this.contract.getLendingFee({
        from: notListed
      });
      expect(resultLendingFee).to.be.bignumber.equal(lendingFee.toString());
    });
  });

  describe("#setManagementFee", function () {
    const newManagementFee = "10";
    it("does not allow a non owner to set managementFee", async function () {
      await expectRevert(
        this.contract.setManagementFee(newManagementFee, { from: notOwner }),
        "Ownable: caller is not the owner"
      );
    });

    it("sets managementFee", async function () {
      await this.contract.setManagementFee(newManagementFee, { from: owner });

      const managementFee = await this.contract.managementFee();
      expect(managementFee).to.be.bignumber.equal(newManagementFee);
    });
  });
  describe("#getManagementFee", function () {
    it("gets price", async function () {
      const resultManagementFee = await this.contract.getManagementFee({
        from: notListed
      });
      expect(resultManagementFee).to.be.bignumber.equal(managementFee);
    });
  });

  describe("#getTotalFee", function () {
    it("gets total fee with lendingFee set in accounting", async function () {
      const lendingFee = ether("2.5")
      await this.contract.setAccounting(1, 2, 3, lendingFee, {
        from: owner
      });
      const expectedTotalFee = ether("9.5") //7+2.5
      const resultTotalFee = await this.contract.getTotalFee({
        from: notListed
      });
      expect(resultTotalFee).to.be.bignumber.equal(expectedTotalFee);
    });
  });
  describe("#getMintingFee", function () {
    it("gets minting fee for 0-50k", async function () {
      const expectedTotalFee = ether("0.003");
      const cash = ether("50000");

      const resultMintingFee = await this.contract.getMintingFee(cash, {
        from: notListed
      });
      expect(resultMintingFee).to.be.bignumber.equal(expectedTotalFee);
    });
    it("gets minting fee for 50-100k", async function () {
      const expectedTotalFee = ether("0.002");
      const cash = ether("100000");
      const resultMintingFee = await this.contract.getMintingFee(cash, {
        from: notListed
      });
      expect(resultMintingFee).to.be.bignumber.equal(expectedTotalFee);
    });
    it("gets minting fee for bigger then 100k", async function () {
      const expectedTotalFee = ether("0.001");
      const cash = ether("100001");
      const resultMintingFee = await this.contract.getMintingFee(cash, {
        from: notListed
      });
      expect(resultMintingFee).to.be.bignumber.equal(expectedTotalFee);
    });
  });

  describe("#setLastMintingFee", function () {
    const newLastMintingFee = "10";
    it("does not allow a non owner to set LastMintingFee", async function () {
      await expectRevert(
        this.contract.setLastMintingFee(newLastMintingFee, { from: notOwner }),
        "Ownable: caller is not the owner"
      );
    });

    it("sets LastMintingFee", async function () {
      await this.contract.setLastMintingFee(newLastMintingFee, { from: owner });

      const managementFee = await this.contract.mintingFee(String(2 ^ 256 - 1));
      expect(managementFee).to.be.bignumber.equal(newLastMintingFee);
    });
  });
  describe("#addMintingFeeBracket", function () {
    const newMintingFeeLimit = ether("100001");
    const newMintingFee = ether("5");

    it("does not allow a non owner to add MintingFee", async function () {
      await expectRevert(
        this.contract.addMintingFeeBracket(newMintingFeeLimit, newMintingFee, { from: notOwner }),
        "Ownable: caller is not the owner"
      );
    });

    it("adds minting fee", async function () {
      await this.contract.addMintingFeeBracket(newMintingFeeLimit, newMintingFee, { from: owner });

      const mintingFeeLimit = await this.contract.mintingFeeBracket("2");
      expect(mintingFeeLimit).to.be.bignumber.equal(newMintingFeeLimit);
      const mintingFee = await this.contract.mintingFee(newMintingFeeLimit);
      expect(mintingFee).to.be.bignumber.equal(newMintingFee);
    });
    it("does not allow to add minting fee smaller then last", async function () {
      await expectRevert(
        this.contract.addMintingFeeBracket(ether("99999"), newMintingFee, { from: owner }),
        "New minting fee bracket needs to be bigger then last one."
      );
    });
  });
  describe("#deleteLastMintingFeeBracket", function () {
    it("does not allow a non owner to delete minting fee", async function () {
      await expectRevert(
        this.contract.deleteLastMintingFeeBracket({ from: notOwner }),
        "Ownable: caller is not the owner"
      );
    });

    it("deletes minting fee", async function () {
      await this.contract.deleteLastMintingFeeBracket({ from: owner });
      const mintingFeeLimit = await this.contract.mintingFeeBracket("1");
      expect(mintingFeeLimit).to.be.bignumber.equal("0");
      const mintingFee = await this.contract.mintingFee(ether("100000"));
      expect(mintingFee).to.be.bignumber.equal("0");
    });
  });
  describe("#changeMintingLimit", function () {
    const newMintingFeeLimit = ether("100001");
    const newMintingFee = ether("5");
    const entryToChange = "1";
    it("does not allow a non owner to change minting fee", async function () {
      await expectRevert(
        this.contract.changeMintingLimit(entryToChange, newMintingFeeLimit, newMintingFee, { from: notOwner }),
        "Ownable: caller is not the owner"
      );
    });

    it("change minting fee", async function () {
      await this.contract.changeMintingLimit(entryToChange, newMintingFeeLimit, newMintingFee, { from: owner });

      const mintingFeeLimit = await this.contract.mintingFeeBracket(entryToChange);
      expect(mintingFeeLimit).to.be.bignumber.equal(newMintingFeeLimit);
      const mintingFee = await this.contract.mintingFee(newMintingFeeLimit);
      expect(mintingFee).to.be.bignumber.equal(newMintingFee);
    });
    it("does not allow to change minting fee smaller then last", async function () {
      await expectRevert(
        this.contract.changeMintingLimit(entryToChange, ether("49000"), newMintingFee, { from: owner }),
        "New minting fee bracket needs to be bigger then last one."
      );
    });
    it("does not allow to change minting fee bigger then next", async function () {
      await expectRevert(
        this.contract.changeMintingLimit("0", ether("100001"), newMintingFee, { from: owner }),
        "New minting fee bracket needs to be smaller then next one."
      );
    });
  });
});
