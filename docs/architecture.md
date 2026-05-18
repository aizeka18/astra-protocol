# Astra Protocol — Architecture & Design Document

**Version:** 1.0  
**Network:** Arbitrum Sepolia (Chain ID 421614)  
**Stack:** Solidity 0.8.24 · OpenZeppelin v5 · Foundry · Next.js 15 · Wagmi v2 · The Graph

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Context — C4 Level 1](#2-system-context--c4-level-1)
3. [Container & Component Diagram](#3-container--component-diagram)
4. [Sequence Diagrams — Critical User Flows](#4-sequence-diagrams--critical-user-flows)
5. [Data Model & Storage Layout](#5-data-model--storage-layout)
6. [Trust Assumptions](#6-trust-assumptions)
7. [Architecture Decision Records (ADR)](#7-architecture-decision-records)
8. [Design Patterns](#8-design-patterns)

---

## 1. Executive Summary

Astra Protocol is a decentralised autonomous organisation (DAO) that governs a constant-product AMM and an ERC-4626 yield vault. Token holders vote on on-chain proposals; passed proposals execute automatically through a Timelock after a minimum delay. All protocol-critical parameters (fees, quorum, vault strategies) are gated behind governance.

**Key properties:**
- Non-custodial: no admin key can unilaterally move user funds.
- Upgradeable vault: implemented via UUPS proxy with upgrade authority held by the Timelock.
- Price-feed security: all AMM prices consumed externally via a Chainlink oracle adapter.
- Transparent governance: every proposal, vote, and delegation is indexed by The Graph for off-chain access without trusting a centralised API.

**Deployed contracts (Arbitrum Sepolia):**

| Contract              | Address |
|-----------------------|---------|
| GovernanceToken (AGT) | `0x6d4820Cf78b1Ca1A7ec9E1ccfB364e283e56F2ba` |
| ProtocolTimelock      | `0x6d8Eb34071be4f4204F58829607dB58698a36c6f` |
| ProtocolGovernor      | `0xD2F3F79699D0Bbb5c3Ce24328cfAcb87b08e6DC5` |
| Treasury              | `0xAeB4c1f32f671f8CB671164f8e50867e3daD180b` |
| AMMFactory            | `0xc373BD9a46dF0946dd2B8f52BfC8F4F5bc95c6dA` |
| ChainlinkOracle       | `0x03393fe5C7870C248b63Fc01aBE7c1639673e7D3` |
| YieldVault (proxy)    | `0xEAe2F21073290ec7cbA7c6140352a805dD9678cE` |
| MockUSDC              | `0xf8cc54cFF031fF0c9AC71728c6F39b9aDe7cB120` |

---

## 2. System Context — C4 Level 1

```
┌──────────────────────────────────────────────────────────────────────┐
│                          External Actors                             │
│                                                                      │
│   ┌───────────┐    ┌───────────────┐    ┌──────────────────────┐    │
│   │  Token    │    │  Governance   │    │  Liquidity           │    │
│   │  Holder   │    │  Proposer     │    │  Provider / Trader   │    │
│   └─────┬─────┘    └──────┬────────┘    └──────────┬───────────┘    │
│         │                 │                        │                │
└─────────┼─────────────────┼────────────────────────┼────────────────┘
          │                 │                        │
          ▼                 ▼                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       Astra Protocol dApp                           │
│                    (Next.js 15 — Arbitrum Sepolia)                  │
│                                                                     │
│  ┌──────────────────┐   ┌─────────────────┐   ┌────────────────┐   │
│  │  Governance UI   │   │   Vault UI      │   │   AMM UI       │   │
│  │  Wagmi / Viem    │   │   Wagmi / Viem  │   │  (read-only)   │   │
│  └────────┬─────────┘   └────────┬────────┘   └───────┬────────┘   │
│           │                      │                    │            │
│           └──────────────────────┴────────────────────┘            │
│                              JSON-RPC                               │
└──────────────────────────────────┬──────────────────────────────────┘
                                   │
           ┌───────────────────────┼───────────────────────┐
           ▼                       ▼                       ▼
┌─────────────────┐   ┌───────────────────────┐  ┌──────────────────┐
│  Smart Contract │   │   The Graph           │  │  Chainlink       │
│  Layer          │   │   Subgraph            │  │  Price Feeds     │
│  (on-chain)     │   │   (indexed data)      │  │  (off-chain)     │
└─────────────────┘   └───────────────────────┘  └──────────────────┘
```

**Actors:**
- **Token Holder** — holds AGT, delegates voting power, votes on proposals.
- **Proposer** — holds ≥ 10,000 AGT voting power, creates governance proposals.
- **Liquidity Provider / Trader** — deposits USDC into the YieldVault or swaps via AMM.

**External Systems:**
- **Arbitrum Sepolia L2** — EVM execution environment; inherits Ethereum L1 security.
- **The Graph** — decentralised indexing; the frontend reads governance history from it.
- **Chainlink** — provides tamper-resistant price feeds consumed by `ChainlinkOracle.sol`.

---

## 3. Container & Component Diagram

```
                           ┌─────────────────────────────────────────────┐
                           │           GOVERNANCE LAYER                  │
                           │                                             │
    propose() ────────────▶│  ProtocolGovernor (Governor v5)            │
    castVote() ───────────▶│  • GovernorSettings (delay=1, period=20)   │
    queue() ──────────────▶│  • GovernorCountingSimple                  │
    execute() ────────────▶│  • GovernorVotesQuorumFraction (4 %)       │
                           │  • GovernorTimelockControl ──────────────┐  │
                           └─────────────────────────────────────────┬┘  │
                                                                      │
                           ┌─────────────────────────────────────────▼┐  │
                           │           TIMELOCK LAYER                 │  │
                           │  ProtocolTimelock (TimelockController)   │  │
                           │  • min delay: 1 block (demo)             │  │
                           │  • Proposer role: Governor               │  │
                           │  • Executor role: anyone (open)          │  │
                           │  • Admin role: Governor                  │  │
                           └──────────────────────────────────────────┘
                                          │
              ┌───────────────────────────┴────────────────────────────┐
              ▼                                                        ▼
┌─────────────────────────┐                            ┌──────────────────────────┐
│     TOKEN LAYER         │                            │     VAULT LAYER          │
│  GovernanceToken (AGT)  │                            │  YieldVault (UUPS proxy) │
│  • ERC-20               │     upgrade via Timelock   │  → YieldVaultV2 (impl)   │
│  • ERC-20Votes (EIP-712)│ ◀──────────────────────── │  • ERC-4626              │
│  • ERC-20Permit         │                            │  • Ownable (Timelock)    │
│  Roles: none (open)     │                            │  underlying: MockUSDC    │
└─────────────────────────┘                            └──────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AMM LAYER                                          │
│  AMMFactory                               AMMPair (per token-pair)              │
│  • creates pairs                          • constant-product k = x · y          │
│  • fee = 30 bp                            • LP token (LPToken.sol)              │
│  • pair registry                          • ChainlinkOracle for fair-value ref  │
└─────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐      ┌──────────────────────────────────────────────┐
│  Treasury            │      │  Oracle Layer                                │
│  • holds protocol    │      │  ChainlinkOracle → AggregatorV3Interface     │
│    fees & grants     │      │  MockAggregatorV3 (for test environments)    │
│  • Timelock-gated    │      │                                              │
└──────────────────────┘      └──────────────────────────────────────────────┘
```

**Access-control roles:**

| Role             | Held by                  | Can do                          |
|------------------|--------------------------|---------------------------------|
| PROPOSER_ROLE    | ProtocolGovernor         | Schedule Timelock operations    |
| EXECUTOR_ROLE    | address(0) = anyone      | Execute matured Timelock ops    |
| CANCELLER_ROLE   | ProtocolGovernor         | Cancel pending Timelock ops     |
| TIMELOCK_ADMIN   | ProtocolGovernor         | Manage Timelock roles           |
| YieldVault owner | ProtocolTimelock         | Trigger UUPS upgrade            |

---

## 4. Sequence Diagrams — Critical User Flows

### 4.1 Governance Flow: Propose → Vote → Execute

```
Actor           Governor         Timelock        Target Contract
  │                │                │                 │
  │─ delegate() ──▶│(Token)          │                 │
  │                │                │                 │
  │─ propose() ───▶│                │                 │
  │                │── emit ProposalCreated            │
  │                │                │                 │
  │  [wait votingDelay = 1 block]   │                 │
  │                │                │                 │
  │─ castVote(1) ─▶│                │                 │
  │                │── emit VoteCast│                 │
  │                │                │                 │
  │  [wait votingPeriod = 20 blocks]│                 │
  │                │                │                 │
  │─ queue() ─────▶│                │                 │
  │                │─ scheduleBatch()▶                │
  │                │                │── emit CallScheduled
  │                │                │                 │
  │  [wait timelockDelay]           │                 │
  │                │                │                 │
  │─ execute() ───▶│                │                 │
  │                │─ executeBatch()▶                 │
  │                │                │─ call target() ▶│
  │                │                │                 │── state change
  │                │                │◀── return        │
  │                │                │                 │
  │                │── emit ProposalExecuted           │
```

### 4.2 YieldVault Deposit & Withdrawal (ERC-4626)

```
User           MockUSDC          YieldVault (Proxy → V2)
  │                │                    │
  │─ approve(vault, amount) ──────────▶ │ (allowance set)
  │                │                    │
  │─ deposit(assets, receiver) ────────▶│
  │                │◀── transferFrom() ─│
  │                │─── transfer ──────▶│ (vault holds assets)
  │                │                    │
  │                │                    │── _mint(shares) to receiver
  │                │                    │── emit Deposit(sender, owner, assets, shares)
  │◀──────────────────────── shares ────│
  │                │                    │
  │  [time passes — vault accrues yield]│
  │                │                    │
  │─ withdraw(assets, receiver, owner) ▶│
  │                │                    │── _burn(shares) from owner
  │                │◀── transfer ───────│ (assets back to receiver)
  │                │                    │── emit Withdraw(...)
  │◀── assets returned ─────────────────│
```

### 4.3 AMM Swap via AMMPair

```
Trader         MockUSDC/MockWETH        AMMFactory        AMMPair
  │                    │                    │                 │
  │── getPair(A, B) ──────────────────────▶│                 │
  │◀── pairAddress ────────────────────────│                 │
  │                    │                    │                 │
  │── approve(pair, amountIn) ────────────────────────────▶  │
  │                    │                    │                 │
  │── swap(amountIn, minOut, recipient) ─────────────────── ▶│
  │                    │                    │           check k invariant
  │                    │◀── transferFrom() ─────────────── ──│
  │                    │── transfer(amountOut) ───────────── ▶│ (to recipient)
  │                    │                    │                 │── emit Swap(...)
  │◀── amountOut ──────│                    │                 │
```

---

## 5. Data Model & Storage Layout

### 5.1 GovernanceToken — `src/token/GovernanceToken.sol`

Inherits `ERC20Votes`. Storage is determined by OpenZeppelin's ERC20 + ERC20Permit + ERC20Votes chain.

| Slot | Variable               | Type       | Notes                          |
|------|------------------------|------------|--------------------------------|
| 0    | `_balances`            | mapping    | address → uint256 balance      |
| 1    | `_allowances`          | mapping    | owner → spender → uint256      |
| 2    | `_totalSupply`         | uint256    |                                |
| 3    | `_name`                | string     | "Astra Governance Token"       |
| 4    | `_symbol`              | string     | "AGT"                          |
| 5–6  | EIP-712 domain         | bytes32    | cached domain separator        |
| 7    | `_nonces`              | mapping    | permit nonces                  |
| 8–9  | `_delegatee`           | mapping    | ERC20Votes delegation map      |
| 10+  | `_checkpoints`         | mapping    | historical vote checkpoints    |

### 5.2 ProtocolGovernor — `src/governance/ProtocolGovernor.sol`

Inherits `Governor` + extensions. Critical storage:

| Variable                 | Location   | Description                              |
|--------------------------|------------|------------------------------------------|
| `_proposals`             | mapping    | proposalId → ProposalCore struct         |
| `_proposalVotes`         | mapping    | proposalId → ProposalVote (for/against)  |
| `_governanceCall`        | address    | pending governance call target           |
| `_name`                  | string     | "Astra Governor"                         |
| `_quorumNumerator`       | checkpoints| historical quorum fraction (4 %)         |
| `_timelock`              | address    | TimelockController address               |
| `_timelockIds`           | mapping    | proposalId → bytes32 operationId         |

### 5.3 YieldVault (UUPS Proxy) — `src/vault/YieldVault.sol`

**Storage collision risk is eliminated by the UUPS pattern** — the implementation contract inherits from `UUPSUpgradeable` which stores the implementation address at the EIP-1967 slot (`0x360894…`) rather than slot 0. The proxy's data slots are:

| Slot       | Variable          | Type    | Notes                                  |
|------------|-------------------|---------|----------------------------------------|
| 0          | `_initialized`    | uint8   | OZ Initializable guard                 |
| 1          | `_owner`          | address | OwnableUpgradeable (Timelock)          |
| 2          | `_asset`          | address | underlying token (MockUSDC)            |
| 3          | `_totalAssets`    | uint256 | total USDC held                        |
| 4          | `_balances`       | mapping | ERC-20 shares per address              |
| 5          | `_totalSupply`    | uint256 | total avTKN shares                     |

EIP-1967 implementation slot (`keccak256("eip1967.proxy.implementation") - 1`):  
→ YieldVaultV2 implementation address

**V1 → V2 upgrade safety:** V2 only appends new variables after slot 5. No existing slots are reused.

### 5.4 AMMPair — `src/amm/AMMPair.sol`

| Slot | Variable     | Type    | Notes                           |
|------|--------------|---------|---------------------------------|
| 0    | `_reserve0`  | uint112 | reserve of token0               |
| 1    | `_reserve1`  | uint112 | reserve of token1               |
| 2    | `factory`    | address | AMMFactory address              |
| 3    | `token0`     | address | lower address of pair           |
| 4    | `token1`     | address | higher address of pair          |
| 5    | `lpToken`    | address | associated LPToken contract     |

---

## 6. Trust Assumptions

### 6.1 Who controls what

| Entity             | Controls                                | Risk if compromised                         |
|--------------------|-----------------------------------------|---------------------------------------------|
| AGT token holders  | Governance outcomes via quorum + votes  | Malicious proposals can pass                |
| ProtocolTimelock   | YieldVault upgrades, Treasury funds     | Can drain vault or steal treasury           |
| ProtocolGovernor   | Timelock PROPOSER + CANCELLER roles     | Can prevent any proposal from executing     |
| Chainlink node ops | Price feed values                       | Oracle manipulation → unfair AMM prices     |
| The Graph indexer  | Historical data served to frontend      | Stale/wrong data; contracts are authoritative |

### 6.2 Timelock authority

All operations scheduled through the Timelock are subject to a minimum delay. During this delay, the CANCELLER (Governor) can abort malicious operations. After the delay expires, **any account** (EXECUTOR = address(0)) can trigger execution — this is intentional to prevent delay-locking of legitimate governance.

### 6.3 Worst-case multisig compromise

There is no multisig in this deployment — authority is fully on-chain via governance. A 4 % quorum of AGT must agree for any proposal to pass. If an attacker accumulates > 50 % of voting power, they can pass arbitrary proposals after the voting period. Mitigations:
- Quorum threshold (4 %)
- Timelock delay gives honest participants time to react
- Token delegation can be revoked before proposal execution

### 6.4 Upgrade safety

The YieldVault proxy can only be upgraded via a governance-approved Timelock transaction. The upgrade function (`_authorizeUpgrade`) reverts unless `msg.sender == owner()` (the Timelock). No EOA can upgrade unilaterally.

---

## 7. Architecture Decision Records

### ADR-001: OpenZeppelin Governor over custom governance

**Context:** The project needed on-chain governance with proposal lifecycle, quorum, and timelock integration.  
**Options considered:**
1. Custom governor contract
2. OpenZeppelin Governor v5 modular extensions
3. Compound Bravo governor (older standard)

**Decision:** OpenZeppelin Governor v5 with `GovernorSettings`, `GovernorCountingSimple`, `GovernorVotes`, `GovernorVotesQuorumFraction`, `GovernorTimelockControl`.

**Consequences:**
- ✅ Audited, battle-tested code — no custom vulnerability surface
- ✅ Modular: each extension is independently replaceable via future governance
- ✅ Native EIP-712 proposal hashing prevents replay
- ⚠️ Proposal threshold (10,000 AGT) must match actual token distribution

---

### ADR-002: ERC-4626 for yield vault

**Context:** A yield-bearing vault needed a standard interface for composability.  
**Options considered:**
1. Custom vault with proprietary accounting
2. ERC-4626 Tokenised Vault Standard

**Decision:** ERC-4626 with `YieldVault.sol` inheriting OpenZeppelin's `ERC4626Upgradeable`.

**Consequences:**
- ✅ Standard interface: any ERC-4626-aware aggregator can integrate without custom adapters
- ✅ shares/assets accounting is audited
- ⚠️ Inflationary attack vector (first-depositor) — mitigated by virtual shares offset in OZ v5

---

### ADR-003: UUPS proxy over Transparent proxy

**Context:** The YieldVault needs to be upgradeable for future yield strategy improvements.  
**Options considered:**
1. No upgrade (immutable vault)
2. Transparent proxy (admin in proxy)
3. UUPS proxy (upgrade logic in implementation)

**Decision:** UUPS (`UUPSUpgradeable`) with `_authorizeUpgrade` gated to Timelock owner.

**Consequences:**
- ✅ Lower deployment and call gas vs Transparent proxy (no admin check on every call)
- ✅ Upgrade authority is fully on-chain — Timelock must approve
- ⚠️ If a broken implementation is deployed, recovery requires another governance vote

---

### ADR-004: Arbitrum Sepolia as deployment target

**Context:** Project requires a live L2 testnet deployment with low gas costs and fast finality.  
**Options considered:**
1. Ethereum Sepolia (L1 testnet — expensive)
2. Arbitrum Sepolia (Arbitrum L2 testnet)
3. Base Sepolia (Coinbase L2 testnet)

**Decision:** Arbitrum Sepolia (Chain ID 421614).

**Consequences:**
- ✅ ~100× cheaper gas than Ethereum L1 — critical for governance (many transactions)
- ✅ EVM-equivalent: all Solidity/Foundry tooling works without modification
- ✅ Arbitrum bridge maintains L1 security for fraud proofs
- ⚠️ Block times are ~0.25 s — governance parameters (votingPeriod=20 blocks) must account for this in production

---

### ADR-005: The Graph for governance data indexing

**Context:** The frontend needs to display proposal history and vote counts without calling the RPC for every page load.  
**Options considered:**
1. Direct RPC calls with `eth_getLogs` on every page load
2. Centralised backend database
3. The Graph decentralised indexing

**Decision:** The Graph subgraph indexing `ProposalCreated`, `VoteCast`, delegation, and vault events.

**Consequences:**
- ✅ Decentralised — no single point of failure for historical data
- ✅ GraphQL queries are typed and composable
- ✅ Automatic real-time sync via event handlers
- ⚠️ Subgraph may lag behind chain by a few blocks (indexing latency)
- ⚠️ Frontend must fall back gracefully when subgraph returns empty data

---

## 8. Design Patterns

### Pattern 1 — Governor Pattern (Compound / OpenZeppelin)

**Used in:** `ProtocolGovernor.sol`  
**Why:** Separates proposal lifecycle (create → vote → queue → execute) from business logic. Each phase is enforced by the contract state machine. Replacing individual phases (e.g., switching to optimistic proposals) requires only swapping a single extension module.

### Pattern 2 — Proxy / Upgradeable (UUPS, EIP-1967)

**Used in:** `YieldVault.sol` + `ERC1967Proxy`  
**Why:** The vault stores user funds that must be protected even as the yield strategy evolves. UUPS puts the upgrade authority in the implementation, preventing a rogue proxy admin from upgrading without governance approval. Storage layout is kept forward-compatible by only appending new variables.

### Pattern 3 — Factory Pattern

**Used in:** `AMMFactory.sol`  
**Why:** A single registry contract deploys and tracks all trading pairs. Routers and integrators only need to know the factory address to discover any pair. The factory enforces pair uniqueness (token0 < token1 ordering) and standardises initialisation.

### Pattern 4 — Vault / Strategy Pattern (ERC-4626)

**Used in:** `YieldVault.sol` / `YieldVaultV2.sol`  
**Why:** ERC-4626 decouples "accounting" (shares ↔ assets conversion) from the "strategy" (how assets earn yield). V2 can introduce a new yield mechanism without changing the external interface. Depositors never need to migrate their positions.

### Pattern 5 — Oracle Adapter Pattern

**Used in:** `ChainlinkOracle.sol` wrapping `AggregatorV3Interface`  
**Why:** Isolates the AMM from Chainlink's specific interface. The adapter checks for stale data (`updatedAt` threshold), handles round ID overflow, and normalises decimal precision. Swapping to a different oracle provider only requires replacing the adapter, not the AMM core.

### Pattern 6 — Timelock / Delay Pattern

**Used in:** `ProtocolTimelock.sol` (TimelockController)  
**Why:** Enforces a mandatory waiting period between governance approval and on-chain execution. This gives token holders and external observers a window to react to potentially harmful proposals (exit funds, signal opposition, trigger emergency cancellation).

### Pattern 7 — Checks-Effects-Interactions (CEI)

**Used in:** `AMMPair.sol` swap and `YieldVault.sol` deposit/withdraw  
**Why:** Prevents reentrancy by performing all state updates before external calls. The AMM updates reserves before transferring output tokens; the vault updates share balances before transferring assets. This is reinforced by OpenZeppelin's `ReentrancyGuard` on critical functions.
