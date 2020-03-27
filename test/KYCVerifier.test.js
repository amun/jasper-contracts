const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");
const { ether } = require("@openzeppelin/test-helpers");

const PersistentStorage = contract.fromArtifact("PersistentStorage");
const KYCVerifier = contract.fromArtifact("KYCVerifier");

describe("KYCVerifier", function() {
  const [owner, listedUser, unlistedUser] = accounts;

  beforeEach(async function() {
    const persistentStorage = await PersistentStorage.new({ from: owner });
    const managementFee = ether("7");
    const minRebalanceAmount = ether("1");
    await persistentStorage.initialize(owner, managementFee, minRebalanceAmount);
    await persistentStorage.setWhitelistedAddress(listedUser, { from: owner });

    this.contract = await KYCVerifier.new({ from: owner });
    await this.contract.initialize(persistentStorage.address);
  });

  describe("#isAddressWhitelisted", function() {
    it("checks whether an address is whitelisted", async function() {
      const isListedUser = await this.contract.isAddressWhitelisted(listedUser);
      expect(isListedUser).to.be.true
    });

    it("tells whether an address is NOT whitelisted", async function() {
      const isListedUser = await this.contract.isAddressWhitelisted(unlistedUser);
      expect(isListedUser).to.be.false
    });
  });
});
