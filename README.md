# Astra Protocol

A decentralised autonomous organisation (DAO) governing a constant-product AMM and an ERC-4626 yield vault, deployed on **Arbitrum Sepolia**.

---

## Project Overview

Astra Protocol lets AGT token holders collectively control protocol parameters — fees, vault strategies, and treasury allocation — through fully on-chain governance. Key primitives:

- **GovernanceToken (AGT)** — ERC-20Votes token; voting power is derived from delegated balance.
- **ProtocolGovernor** — OpenZeppelin Governor v5; enforces the propose → vote → queue → execute lifecycle.
- **ProtocolTimelock** — mandatory delay between governance approval and on-chain execution.
- **YieldVault** — ERC-4626 vault (UUPS upgradeable); accepts MockUSDC, issues avTKN shares.
- **AMMFactory / AMMPair** — constant-product AMM with Chainlink-backed fair-value reference.

---

## Deployed & Verified Contracts — Arbitrum Sepolia (Chain ID 421614)

| Contract              | Address | Explorer |
|-----------------------|---------|---------|
| GovernanceToken (AGT) | `0x6d4820Cf78b1Ca1A7ec9E1ccfB364e283e56F2ba` | [Arbiscan](https://sepolia.arbiscan.io/address/0x6d4820Cf78b1Ca1A7ec9E1ccfB364e283e56F2ba) |
| ProtocolTimelock      | `0x6d8Eb34071be4f4204F58829607dB58698a36c6f` | [Arbiscan](https://sepolia.arbiscan.io/address/0x6d8Eb34071be4f4204F58829607dB58698a36c6f) |
| ProtocolGovernor      | `0xD2F3F79699D0Bbb5c3Ce24328cfAcb87b08e6DC5` | [Arbiscan](https://sepolia.arbiscan.io/address/0xD2F3F79699D0Bbb5c3Ce24328cfAcb87b08e6DC5) |
| Treasury              | `0xAeB4c1f32f671f8CB671164f8e50867e3daD180b` | [Arbiscan](https://sepolia.arbiscan.io/address/0xAeB4c1f32f671f8CB671164f8e50867e3daD180b) |
| MockUSDC              | `0xf8cc54cFF031fF0c9AC71728c6F39b9aDe7cB120` | [Arbiscan](https://sepolia.arbiscan.io/address/0xf8cc54cFF031fF0c9AC71728c6F39b9aDe7cB120) |
| AMMFactory            | `0xc373BD9a46dF0946dd2B8f52BfC8F4F5bc95c6dA` | [Arbiscan](https://sepolia.arbiscan.io/address/0xc373BD9a46dF0946dd2B8f52BfC8F4F5bc95c6dA) |
| ChainlinkOracle       | `0x03393fe5C7870C248b63Fc01aBE7c1639673e7D3` | [Arbiscan](https://sepolia.arbiscan.io/address/0x03393fe5C7870C248b63Fc01aBE7c1639673e7D3) |
| YieldVault (impl)     | `0x1aa43c68e7e9cf1669eccf5f8f704f766128d466` | [Arbiscan](https://sepolia.arbiscan.io/address/0x1aa43c68e7e9cf1669eccf5f8f704f766128d466) |
| YieldVault (proxy)    | `0xEAe2F21073290ec7cbA7c6140352a805dD9678cE` | [Arbiscan](https://sepolia.arbiscan.io/address/0xEAe2F21073290ec7cbA7c6140352a805dD9678cE) |

---

## Repository Structure

```
astra-protocol/
├── src/
│   ├── governance/   # ProtocolGovernor, ProtocolTimelock, Treasury
│   ├── token/        # GovernanceToken (AGT), LPToken
│   ├── amm/          # AMMFactory, AMMPair
│   ├── oracle/       # ChainlinkOracle, MockAggregatorV3
│   ├── vault/        # YieldVault, YieldVaultV2
│   ├── mocks/        # MockUSDC, MockWETH
│   └── interfaces/   # IAMM, IGovernanceToken, IVault
├── test/
│   ├── unit/         # per-contract unit tests
│   ├── integration/  # end-to-end protocol flow
│   ├── fork/         # Chainlink, Uniswap, USDC fork tests
│   ├── invariant/    # stateful invariant fuzzing
│   └── security/     # reentrancy & security case studies
├── script/
│   ├── Deploy.s.sol
│   └── VerifyDeployment.s.sol
├── subgraph/         # The Graph subgraph (schema, mappings, ABIs)
├── docs/
│   └── architecture.md   # 6-page architecture & design document
├── astra-frontend/   # Next.js 15 dApp (Wagmi v2, The Graph)
└── broadcast/        # Foundry deployment records
```

---

## Running Tests

Requires [Foundry](https://getfoundry.sh/).

```bash
# Install dependencies
forge install

# Run full test suite
forge test

# Run with verbose output
forge test -vvv

# Run a specific test file
forge test --match-path test/unit/Governor.t.sol -vvv

# Generate coverage report
forge coverage --report lcov
```

**Coverage summary:** 97.16 % lines · 100 % functions · 76 % branches

---

## Deployment

```bash
# Copy and fill in environment variables
cp .env.example .env
# Required: PRIVATE_KEY, ARBITRUM_SEPOLIA_RPC_URL, ARBISCAN_API_KEY

# Deploy all contracts to Arbitrum Sepolia
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv

# Verify deployment addresses
forge script script/VerifyDeployment.s.sol \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

---

## Frontend

Requires Node.js 20+ and npm.

```bash
cd astra-frontend

# Install dependencies
npm install

# Set environment variables (optional — app works without them)
# NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=<your-id>
# NEXT_PUBLIC_SUBGRAPH_URL=<your-subgraph-url>

# Start development server
npm run dev
# → http://localhost:3000

# Production build
npm run build && npm start
```

**Wallet:** MetaMask (required) or WalletConnect (optional). Switch to **Arbitrum Sepolia** when prompted.

---

## The Graph Subgraph

Subgraph source is in `subgraph/`. It indexes governance proposals, votes, delegations, and YieldVault deposits.

```bash
cd subgraph

# Install Graph CLI
npm install

# Generate types from schema and ABIs
npm run codegen

# Build WebAssembly mappings
npm run build

# Deploy to The Graph Studio
# (requires authentication: graph auth --studio <deploy-key>)
npm run deploy
```

**Documented queries:** see [`subgraph/queries.graphql`](subgraph/queries.graphql)  
**Schema entities:** Proposal · Vote · Delegation · TokenHolder · VaultDeposit · VaultWithdrawal

---

## Architecture

See [`docs/architecture.md`](docs/architecture.md) for:
- System context diagram (C4 Level 1)
- Container / component diagram with access-control roles
- Sequence diagrams for governance, vault deposit, and AMM swap flows
- Storage layout for every upgradeable contract
- Trust assumptions and worst-case analysis
- 5 Architecture Decision Records (ADR)
- 7 design patterns with justification

---

## Security

See [`audit-report.md`](audit-report.md) — 0 critical / 0 high / 0 medium findings.

Key protections:
- Checks-Effects-Interactions in AMM and vault
- Timelock delay on all governance-controlled state changes
- Chainlink staleness check (updatedAt threshold) in oracle adapter
- UUPS upgrade gated to Timelock; no EOA can upgrade unilaterally
- ERC-20Votes snapshots prevent flash-loan voting attacks
