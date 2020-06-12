const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");
const { expectRevert } = require("@openzeppelin/test-helpers");

const KYCVerifier = contract.fromArtifact("KYCVerifier");

describe("KYCVerifier", function() {
  const [owner, bridge, listedUser, unlistedUser, notOwner] = accounts;

  beforeEach(async function() {
    this.contract = await KYCVerifier.new({ from: owner });
    await this.contract.initialize(owner);
    await this.contract.setWhitelistedAddress(listedUser, { from: owner }); // listedUser is whitelisted
    await this.contract.setBridge(bridge, { from: owner });
  });

  describe("#isAddressWhitelisted", function() {
    it("checks whether an address is whitelisted", async function() {
      const isListedUser = await this.contract.isAddressWhitelisted(listedUser);
      expect(isListedUser).to.be.true;
    });

    it("tells whether an address is NOT whitelisted", async function() {
      const isListedUser = await this.contract.isAddressWhitelisted(
        unlistedUser
      );
      expect(isListedUser).to.be.false;
    });
  });

  describe("#setWhitelistedAddress", function() {
    it("does not allow a non owner to add a whitelisted address", async function() {
      await expectRevert(
        this.contract.setWhitelistedAddress(notOwner, { from: notOwner }),
        "caller is not the owner or bridge"
      );
    });

    it("does not allow empty address to be whitelisted", async function() {
      await expectRevert(
        this.contract.setWhitelistedAddress(
          "0x0000000000000000000000000000000000000000",
          { from: owner }
        ),
        "adddress must not be empty"
      );
    });

    it("allows bridge to whitelisted address", async function() {
      await this.contract.setWhitelistedAddress(notOwner, {
        from: bridge,
      });

      const isAddressAdded = await this.contract.whitelistedAddresses(notOwner);
      expect(isAddressAdded).to.be.true;
      await this.contract.removeWhitelistedAddress(notOwner, { from: bridge });
    });

    it("adds whitelisted address", async function() {
      await this.contract.setWhitelistedAddress(notOwner, {
        from: owner,
      });

      const isAddressAdded = await this.contract.whitelistedAddresses(notOwner);
      expect(isAddressAdded).to.be.true;
    });
  });

  describe("#batchWhitelistedAddress", function() {
    it("does not allow a non owner to add multiple addresses", async function() {
      await expectRevert(
        this.contract.batchWhitelistedAddress([notOwner, owner], {
          from: notOwner,
        }),
        "caller is not the owner or bridge"
      );
    });

    it("does not allow an empty address to be whitelisted", async function() {
      await expectRevert(
        this.contract.batchWhitelistedAddress(
          [owner, "0x0000000000000000000000000000000000000000"],
          { from: owner }
        ),
        "adddress must not be empty"
      );
    });

    it("allows bridge or owner to batch whitelisted addresses", async function() {
      // as bridge
      await this.contract.batchWhitelistedAddress([notOwner, owner], {
        from: bridge,
      });

      let isAddressAdded = await this.contract.whitelistedAddresses(notOwner);
      expect(isAddressAdded).to.be.true;
      await this.contract.removeWhitelistedAddress(notOwner, { from: bridge });

      // as owner
      await this.contract.batchWhitelistedAddress([notOwner, owner, unlistedUser], {
        from: owner,
      });

      isAddressAdded = await this.contract.whitelistedAddresses(unlistedUser);
      expect(isAddressAdded).to.be.true;
    });
  });

  describe("#removeWhitelistedAddress", function() {
    beforeEach(async function() {
      await this.contract.setWhitelistedAddress(notOwner, { from: owner });
    });

    it("prohibits a non owner from removing whitelisted user", async function() {
      await expectRevert(
        this.contract.removeWhitelistedAddress(notOwner, {
          from: notOwner,
        }),
        "caller is not the owner or bridge"
      );
    });

    it("does not allow an address to be removed which has not been added", async function() {
      await expectRevert(
        this.contract.removeWhitelistedAddress(unlistedUser, { from: owner }),
        "address must be added to be removed allowed"
      );
    });

    it("removes the whitelisted user", async function() {
      await this.contract.removeWhitelistedAddress(notOwner, {
        from: owner,
      });

      const isAddressAdded = await this.contract.whitelistedAddresses(notOwner);
      expect(isAddressAdded).to.be.false;
    });
  });

  describe("#updateWhitelistedAddress", function() {
    beforeEach(async function() {
      await this.contract.setWhitelistedAddress(notOwner, { from: owner });
    });

    it("prohibits a non owner from updating whitelisted address", async function() {
      await expectRevert(
        this.contract.updateWhitelistedAddress(notOwner, unlistedUser, {
          from: notOwner,
        }),
        "caller is not the owner or bridge"
      );
    });

    it("updates an whitelisted user", async function() {
      await this.contract.updateWhitelistedAddress(notOwner, unlistedUser, {
        from: owner,
      });

      const isAddressAdded = await this.contract.whitelistedAddresses(
        unlistedUser
      );
      expect(isAddressAdded).to.be.true;
      const isAddressAdded2 = await this.contract.whitelistedAddresses(
        notOwner
      );
      expect(isAddressAdded2).to.be.false;
    });
  });
});
