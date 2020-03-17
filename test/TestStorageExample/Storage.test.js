const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");

const { expectEvent, expectRevert } = require("@openzeppelin/test-helpers");

const Storage = contract.fromArtifact("Storage");

describe("Storage", function() {
  const [owner, notOwner] = accounts;

  beforeEach(async function() {
    this.contract = await Storage.new({ from: owner });
    await this.contract.initialize(owner);
  });

  describe("#insertInstrument", function() {
    it("does not allow a non owner to add an instrument", async function() {
      await expectRevert(
        this.contract.insertInstrument("ABTC", { from: notOwner }),
        "Ownable: caller is not the owner"
      );
    });

    it("is not able to add the same instrument twice", async function() {
      this.contract.insertInstrument("AETH", { from: owner });

      await expectRevert(
        this.contract.insertInstrument("AETH", { from: owner }),
        "instrument already exists"
      );
    });

    it("adds instrument", async function() {
      const instrumentCounter = (
        await this.contract.instrumentCounter()
      ).toNumber();
      const incrementedCounter = instrumentCounter + 1;

      await this.contract.insertInstrument("ABTC", { from: owner });

      const abtcIndex = (
        await this.contract.getInstrumentIndex("ABTC")
      ).toNumber();

      expect(abtcIndex).to.equal(incrementedCounter);
      expect((await this.contract.instrumentCounter()).toNumber()).to.equal(
        incrementedCounter
      );
    });

    it("emits AddInstrument", async function() {
      const receipt = await this.contract.insertInstrument("HODL", {
        from: owner
      });

      expectEvent(receipt, "AddInstrument", { addedInstrument: "HODL" });
    });
  });

  describe("#addAllowedInstruments", function() {
    beforeEach(async function() {
      await this.contract.insertInstrument("ABTC", { from: owner });
    });

    it("prohibits a non owner from adding allowed instruments to user", async function() {
      await expectRevert(
        this.contract.addAllowedInstruments(notOwner, "ABTC", {
          from: notOwner
        }),
        "Ownable: caller is not the owner"
      );
    });

    it("does not allow an instrument which has not been added yet", async function() {
      await expectRevert(
        this.contract.addAllowedInstruments(notOwner, "AETH", { from: owner }),
        "instrument does not exist"
      );
    });

    it("adds allowed instrument to user", async function() {
      const abtcIndex = await this.contract.getInstrumentIndex("ABTC");

      await this.contract.addAllowedInstruments(notOwner, "ABTC", {
        from: owner
      });
      const userAllowedInstruments = await this.contract.getUserAllowedInstruments(
        notOwner
      );

      expect(userAllowedInstruments).to.deep.equal([abtcIndex]);
    });
  });
});
