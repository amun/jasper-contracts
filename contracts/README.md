# Smart Contract Overview

### Workflows Handled by Smart Contracts:

- Creation and Redemption
- Daily Rebalance and Threshold Rebalance
- Composition PCF And Funding Rate

### List of Smart Contracts:

- /Admin Multi Sig
  - Inverse Provider MultiSig
  - Owner MultiSig
- Token Swap Manager
- Cash Pool
- Composition Calculator
- Inverse Token
- KYC Verifier
- Persistent Storage

### Types of Contracts:

- Persistent Storage Contract
  - Stores All State and Financial Accounting Variables
  - Easy Read Access for Client-Side Applications
- Delegate Contracts (Contracts that can be upgraded)
  - All Contracts that live in the `contracts/` directory
- Proxy Contract (i.e. Upgrade + Version Manager)
  - Handled Behind the Scenes by OpenZeppelin SDK
  - `npm run upgrade` // upgrade contract

### User Roles:

- Contract Owner
  - Multi-Sig owner of each Proxy Contract
- Inverse Provider
  - Multi-Sig owner of the Token Swap Manager
- Whitelisted Market Maker
  - User who can participate in Creation + Redemption Process
- HODLER
  - Token Holder w/o Creation + Redemption Rights
