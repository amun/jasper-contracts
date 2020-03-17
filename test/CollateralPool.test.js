const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");

const { expectRevert } = require("@openzeppelin/test-helpers");

const ERC20WithMinting = contract.fromArtifact("InverseToken");
const CollateralPool = contract.fromArtifact("CollateralPool");
const PersistentStorage = contract.fromArtifact("PersistentStorage");
const KYCVerifier = contract.fromArtifact("KYCVerifier");

describe("CollateralPool", function() {
  const [owner, user, anotherUser] = accounts;
  let token, kycVerifier, persistentStorage;
  this.timeout(5000);

  beforeEach(async function() {
    // initialize token
    token = await ERC20WithMinting.new({ from: owner });
    await token.initialize("Test Token", "TT", 18);
    await token.mintTokens(user, 10, { from: owner });

    // initialize storage and kyc verifier
    persistentStorage = await PersistentStorage.new({ from: owner });
    await persistentStorage.initialize(owner);
    await persistentStorage.setWhitelistedAddress(user, { from: owner }); // user is whitelisted
    kycVerifier = await KYCVerifier.new({owner});
    await kycVerifier.initialize(persistentStorage.address);

    // initialize collateral pool
    this.contract = await CollateralPool.new({ from: owner });
    await this.contract.initialize(owner, kycVerifier.address);
  });

  describe("#moveTokenToPool", function() {
    beforeEach(async function() {
      await token.approve(this.contract.address, 5, { from: user });
    });

    it("does not allow a non owner to move tokens to pool", async function() {
      await expectRevert(
        this.contract.moveTokenToPool(token.address, user, 5, { from: user }),
        "Ownable: caller is not the owner"
      );
    });

    it("does not allow a non whitelisted address to move tokens to pool", async function() {
      await expectRevert(
        this.contract.moveTokenToPool(token.address, anotherUser, 5, { from: owner }),
        "only whitelisted address are allowed to move tokens to pool"
      );
    });

    it("cannot transfer more funds to pool than allowed", async function() {
      await expectRevert(
        this.contract.moveTokenToPool(token.address, user, 8, { from: owner }),
        "cannot move more funds than allowed"
      );
    });

    it("moves transfers from user to pool", async function() {
      await this.contract.moveTokenToPool(token.address, user, 5, { from: owner });
      const poolFundsInTokens = await token.balanceOf(this.contract.address);

      expect(poolFundsInTokens).to.be.bignumber.equal("5");
    });
  });

  describe("#moveTokenfromPool", function() {
    beforeEach(async function() {
      await token.approve(this.contract.address, 5, { from: user });
      await this.contract.moveTokenToPool(token.address, user, 5, { from: owner });
    });

    it("does not allow a non owner to move tokens from pool", async function() {
      await expectRevert(
        this.contract.moveTokenfromPool(token.address, anotherUser, 5, { from: anotherUser }),
        "Ownable: caller is not the owner"
      );
    });

    it("cannot transfer more funds from pool than owned", async function() {
      await expectRevert(
        this.contract.moveTokenfromPool(token.address, anotherUser, 8, { from: owner }),
        "cannot move more funds than owned"
      );
    });

    it("moves transfers from pool to destination address", async function() {
      await this.contract.moveTokenfromPool(token.address, anotherUser, 5, { from: owner });
      const anotherUserTokens = await token.balanceOf(anotherUser);

      expect(anotherUserTokens).to.be.bignumber.equal("5");
    });
  });
});
