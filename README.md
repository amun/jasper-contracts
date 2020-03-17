# Setup Instructions

Install Dependencies:

```
npm install
```

Start Local ETH Blockchain:

```
npm run dev
```

Reset contracts (compile, deploy, mint USDC, set data in DB)

```
# From the Contracts dir, run:
npm run reset:contracts <ownerAddress>
# Note that ownerAddress in dev is 0x9e74E6Be10B63A7442184dFFD633fbed80175B34
```

Compile Contracts

```
npm run compile
```

Deploy Contract

```
npm run deploy
```

Upgrade Contract

```
npm run upgrade
```

Mint USDC (in development)

```
Run the mintUSDC.js script in the backend/scripts folder (it will mint 10K USDC to the first account on ganache on every run)
```

Test contracts

- These are best structured by mirroring the contracts directory: for each `.sol` file there, create a corresponding `.test.js` file.

```
npm test
```

For more information on testing smart contracts go to [https://docs.openzeppelin.com/learn/writing-automated-tests](https://docs.openzeppelin.com/learn/writing-automated-tests) and [https://docs.openzeppelin.com/test-environment/0.1/api](https://docs.openzeppelin.com/test-environment/0.1/api)

# General Dapp Arichitecture

## The Dapp is broken down into 4 components:

- Amun Frontend (UI for KYC, Creation/Redemption, and Token Management)
- Amun Backend (User Database and API Wrapper for Smart Contract Functions)
- Token Swap Smart Contract System (Responsible for Token Swap Management + Portfolio Composition Calcuation)
- Onyx Trading Engine (Processes creation, redemption, and rebalance)

## Creation and Redemption

The steps involved in CREATE and REDEEM processes are illustrated below

### CREATE

- KYC’d Authorised User (AU) sends USDC (stablecoin) to the Token Swap Manager.
- The Oracle reads the CREATE request and initiates an order at the Onyx Trading Engine (OTE).
- OTE short sells a dollar-equivalent amount of crypto.
- Upon successful order placement, The Token Swap Manager mints inverse tokens to the AU's address.

![](create_order.png)

### REDEEM

- Authorised User (AU) sends inverse tokens to the Token Swap Manager.
- The Oracle reads the REDEEM request and initiates an order at the Onyx Trading Engine (OTE).
- OTE buys the appropriate value of crypto and repays the original crypto-denominated loan.
- The Token Manager transfers USDC from the Collateral Pool to the AU and burns the previously sent inverse tokens.

![](redeem_order.png)

## Daily Rebalance and Threshold Rebalance

A rebalance will be ordered by the Onyx Trading Engine during two events: 1) 5pm CET during a **Daily Rebalance** or 2) a price increase of 33% within a 24hr period, i.e. a **Threshold Rebalance**. During a rebalance, the Onyx Trading Engine engages in one of two actions depending on crypto price: 1) increase short exposure or 2) decrease short exposure. The rebalance workflow is detailed below:

- Onyx Trading Engine (OTE) listens for the Time or a Threshold Price to be reached.
- OTE reads the Crypto Price Feed and decides to either **increase or decrease short exposure**.
- OTE adjusts the Collateral Pool and initiates a re-calculation of the NAV/Cash Position of the Inverse Tokens.

![](increase_exposure.png)

![](decrease_exposure.png)

## Composition Calculator

A modified version of the Portfolio Composition File is re-calculated with each succesful create, redeem, or rebalance. Below are the function definitions and accounting values that should be calculated in the Composition Calculator.

```
contract CompositionCalculator is Initializable {

  function calculateNAV() {  }

  function calculateCashPosition() {  }

  function calculateOutstandingLoanPositions() { }

  function calculateLoanRepaymentsAndAccruedFee() {  }

  function calculateBlendedLendingFee() { }

  function calculateFundingRate() { }

  function calculatePCF() { }

  function calculateDailyRebalancePCF() { }

  function calculateThresholdRebalancePCF() { }

}
```
