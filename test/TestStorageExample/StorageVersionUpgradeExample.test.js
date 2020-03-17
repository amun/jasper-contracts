const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");

const Storage_V0 = contract.fromArtifact("Storage_V0");
const Storage_V1 = contract.fromArtifact("Storage_V1");

describe("Storage_V0", function() {
  const [owner] = accounts;

  beforeEach(async function() {
    this.contract = await Storage_V0.new({ from: owner });
    await this.contract.initialize(owner);
  });

  it("shows intrument counter Storage.sol", async function() {
    await this.contract.insertInstrument("HODL", { from: owner });

    const instrumentCounter = (
      await this.contract.instrumentCounter()
    );
    const result = await this.contract.test_storage_v0();

    expect(instrumentCounter).to.deep.equal(result);
  });
});

describe("Storage_V1", function() {
  const [owner] = accounts;

  beforeEach(async function() {
    this.contract = await Storage_V1.new({ from: owner });
    await this.contract.initialize(owner);
  });

  it("shows intrument counter Storage.solm plus 1", async function() {
    const instrumentCounter = (
      await this.contract.instrumentCounter()
    ).toNumber();
    const result = (await this.contract.test_storage_v1()).toNumber();

    expect(instrumentCounter + 1).to.deep.equal(result);
  });
});
