const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");

const PersistentStorage = contract.fromArtifact("PersistentStorage");
const KYCVerifier = contract.fromArtifact("KYCVerifier");

describe("KYCVerifier", function() {
  const [owner, listedUser, unlistedUser] = accounts;

  beforeEach(async function() {
    persistentStorage = await PersistentStorage.new({ from: owner });
    await persistentStorage.initialize(owner);
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
