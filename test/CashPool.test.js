const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");

const { expectRevert, ether } = require("@openzeppelin/test-helpers");

const ERC20WithMinting = contract.fromArtifact("InverseToken");
const CashPool = contract.fromArtifact("CashPool");
const PersistentStorage = contract.fromArtifact("PersistentStorage");
const KYCVerifier = contract.fromArtifact("KYCVerifier");
const sixtyPercentInArrayFraction = [3, 5];

describe("CashPool", function() {
  const [owner, user, anotherUser, tokenSwap] = accounts;
  let token, kycVerifier, persistentStorage;
  this.timeout(5000);
  const coldStorage = accounts[9];
  const amountOfTokensToPool = 5;
  const sixtyPercentOfAmountOfTokensToPool =
    (amountOfTokensToPool * sixtyPercentInArrayFraction[0]) /
    sixtyPercentInArrayFraction[1];

  beforeEach(async function() {
    // initialize storage and kyc verifier
    persistentStorage = await PersistentStorage.new({ from: owner });
    const managementFee = ether("7");
    const minRebalanceAmount = ether("1");
    const lastMintingFee = ether("0.001");
    const balancePrecision = 12;
    const minimumMintingFee = ether("5");
    const minimumTrade = ether("50");
    await persistentStorage.initialize(
      owner,
      managementFee,
      minRebalanceAmount,
      balancePrecision,
      lastMintingFee,
      minimumMintingFee,
      minimumTrade
    );
    await persistentStorage.addMintingFeeBracket(
      ether("50000"),
      ether("0.003"),
      { from: owner }
    ); //0.3%
    await persistentStorage.addMintingFeeBracket(
      ether("100000"),
      ether("0.002"),
      { from: owner }
    ); //0.2%
    await persistentStorage.setTokenSwapManager(tokenSwap, { from: owner });
  
    // initialize token
    token = await ERC20WithMinting.new({ from: owner });
    await token.initialize(
      "Test Token",
      "TT",
      18,
      persistentStorage.address,
      owner
    );
    await token.mintTokens(user, 10, { from: owner });

    kycVerifier = await KYCVerifier.new({ from: owner });
    await kycVerifier.initialize(owner);
    await kycVerifier.setWhitelistedAddress(user, { from: owner }); // user is whitelisted

    // initialize cash pool
    this.contract = await CashPool.new({ from: owner });
    await this.contract.initialize(
      owner,
      kycVerifier.address,
      coldStorage,
      sixtyPercentInArrayFraction
    );
    await this.contract.addTokenManager(tokenSwap, {from: owner})
  });

  describe("#moveTokenToPool", function() {
    beforeEach(async function() {
      await token.approve(this.contract.address, amountOfTokensToPool, {
        from: user
      });
    });

    it("does not allow a non owner to move tokens to pool", async function() {
      await expectRevert(
        this.contract.moveTokenToPool(
          token.address,
          user,
          amountOfTokensToPool,
          { from: user }
        ),
        "caller is not the owner or an approved token swap manager"
      );
    });

    it("does not allow a non whitelisted address to move tokens to pool", async function() {
      await expectRevert(
        this.contract.moveTokenToPool(
          token.address,
          anotherUser,
          amountOfTokensToPool,
          { from: owner }
        ),
        "only whitelisted address are allowed to move tokens to pool"
      );
    });

    it("cannot transfer more funds to pool than allowed", async function() {
      await expectRevert(
        this.contract.moveTokenToPool(token.address, user, 8, { from: owner }),
        "ERC20: transfer amount exceeds allowance -- Reason given: ERC20: transfer amount exceeds allowance"
      );
    });

    it("moves transfers from user to pool taking a percentage to cold storage", async function() {
      await this.contract.moveTokenToPool(
        token.address,
        user,
        amountOfTokensToPool,
        { from: owner }
      );
      const poolFundsInTokens = await token.balanceOf(this.contract.address);
      const coldStorageTokens = await token.balanceOf(coldStorage);

      expect(poolFundsInTokens).to.be.bignumber.equal(
        (amountOfTokensToPool - coldStorageTokens.toNumber()).toString()
      );
      expect(coldStorageTokens).to.be.bignumber.equal(
        sixtyPercentOfAmountOfTokensToPool.toString()
      );
    });
  });

  describe("#moveTokenfromPool", function() {
    beforeEach(async function() {
      await token.approve(this.contract.address, amountOfTokensToPool, {
        from: user
      });
      await this.contract.moveTokenToPool(
        token.address,
        user,
        amountOfTokensToPool,
        { from: owner }
      );
    });

    it("does not allow a non owner to move tokens from pool", async function() {
      await expectRevert(
        this.contract.moveTokenfromPool(
          token.address,
          anotherUser,
          amountOfTokensToPool,
          { from: anotherUser }
        ),
        "caller is not the owner or an approved token swap manager"
      );
    });

    it("cannot transfer more funds from pool than owned", async function() {
      await expectRevert(
        this.contract.moveTokenfromPool(token.address, anotherUser, 8, {
          from: owner
        }),
        "ERC20: transfer amount exceeds balance -- Reason given: ERC20: transfer amount exceeds balance"
      );
    });

    it("moves transfers from pool to destination address", async function() {
      const contractTokenBalance = await token.balanceOf(this.contract.address);
      await this.contract.moveTokenfromPool(
        token.address,
        anotherUser,
        contractTokenBalance,
        { from: owner }
      );
      const anotherUserTokens = await token.balanceOf(anotherUser);

      expect(anotherUserTokens).to.be.bignumber.equal(contractTokenBalance);
    });
  });

  describe("#setColdStorage", function() {
    it("does NOT allow a NON owner to set a new cold storage", async function() {
      await expectRevert(
        this.contract.setColdStorage(anotherUser, { from: anotherUser }),
        "Ownable: caller is not the owner"
      );
    });

    it("does NOT allow to set empty cold storage address", async function() {
      await expectRevert(
        this.contract.setColdStorage(
          "0x0000000000000000000000000000000000000000",
          { from: owner }
        ),
        "address cannot be empty"
      );
    });

    it("allows owner to set a new cold storage address", async function() {
      this.contract.setColdStorage(anotherUser, { from: owner });

      const coldStorage = await this.contract.coldStorage();
      expect(coldStorage).to.be.equal(anotherUser);
    });
  });

  describe("#setPercentageOfFundsForColdStorage", function() {
    it("does NOT allow a NON owner to set percentage of funds for cold storage", async function() {
      await expectRevert(
        this.contract.setPercentageOfFundsForColdStorage([1, 2], {
          from: anotherUser
        }),
        "Ownable: caller is not the owner"
      );
    });

    it("does NOT allow to set empty denominator", async function() {
      await expectRevert(
        this.contract.setPercentageOfFundsForColdStorage([0, 0], {
          from: owner
        }),
        "denominator should not be zero"
      );
    });

    it("cannot set more than 100% of funds to move to cold wallet", async function() {
      await expectRevert(
        this.contract.setPercentageOfFundsForColdStorage([2, 1], {
          from: owner
        }),
        "cannot set more than 100% for coldstorage"
      );
    });

    it("allows owner to set a new percentage funds for cold storage address values", async function() {
      const zeroPercentInFraction = [0, 1];
      this.contract.setPercentageOfFundsForColdStorage(zeroPercentInFraction, {
        from: owner
      });

      const percentageOfFundsForColdStorageFirstElement = await this.contract.percentageOfFundsForColdStorage(
        0
      );
      const percentageOfFundsForColdStorageSecondElement = await this.contract.percentageOfFundsForColdStorage(
        1
      );

      expect(percentageOfFundsForColdStorageFirstElement).to.be.bignumber.equal(
        "0"
      );
      expect(
        percentageOfFundsForColdStorageSecondElement
      ).to.be.bignumber.equal("1");
    });
  });
});
