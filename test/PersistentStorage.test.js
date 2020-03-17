const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");

const { expectEvent, expectRevert, time } = require("@openzeppelin/test-helpers");

const PersitentStorage = contract.fromArtifact("PersistentStorage");

const getDateForBlockTime = async () => {
  const latestBlockTime = await time.latest();
  const latestBlockTimestamp = latestBlockTime.toNumber() * 1000;

  const dateObj = new Date(latestBlockTimestamp);
  const month = dateObj.getUTCMonth() + 1; //months from 1-12
  const day = dateObj.getUTCDate();
  const year = dateObj.getUTCFullYear();

  return year * 10000 + month * 100 + day;
};
describe("PersitentStorage", function () {
  const [owner, notOwner, notListed] = accounts;

  beforeEach(async function () {
    this.contract = await PersitentStorage.new({ from: owner });
    await this.contract.initialize(owner);
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

    it("sets Accounting values and allows for overriding", async function () {
      await this.contract.setAccounting(1, 2, 3, 4, {
        from: owner
      });

      const result = await this.contract.getAccounting(await getDateForBlockTime());
      for (let index = 0; index < result.length; index++) {
        expect(result[index]).to.be.bignumber.equal(index + 1);
      }

      // overriding
      await this.contract.setAccounting(6, 7, 8, 9, {
        from: owner
      });

      for (let index = 0; index < result.length; index++) {
        expect(result[index]).to.be.bignumber.equal(index + 6);
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
});
