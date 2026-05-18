/**
 * src/lib/subgraph.ts
 *
 * Fetches DAO governance data from The Graph subgraph instead of reading
 * directly from the contract — satisfies the "indexed data from subgraph" requirement.
 *
 * To use your own subgraph:
 * 1. Deploy a subgraph at https://thegraph.com/studio/
 * 2. Replace SUBGRAPH_URL with your deployment URL
 */

// ─── Config ──────────────────────────────────────────────────────────────────
// Replace with your actual subgraph URL from The Graph Studio
const SUBGRAPH_URL =
  process.env.NEXT_PUBLIC_SUBGRAPH_URL ??
  'https://api.studio.thegraph.com/query/YOUR_ID/astra-governance/version/latest'

// ─── Types ───────────────────────────────────────────────────────────────────

export interface SubgraphProposal {
  id: string
  proposalId: string
  proposer: string
  description: string
  startBlock: string
  endBlock: string
  status: 'Active' | 'Pending' | 'Succeeded' | 'Defeated' | 'Queued' | 'Executed' | 'Canceled'
  forVotes: string
  againstVotes: string
  abstainVotes: string
  createdAt: string
  transactions: SubgraphVote[]
}

export interface SubgraphVote {
  id: string
  voter: string
  support: number // 0=against, 1=for, 2=abstain
  weight: string
  reason: string
  blockTimestamp: string
}

export interface SubgraphDelegate {
  id: string
  delegator: string
  toDelegate: string
  blockTimestamp: string
}

// ─── GraphQL queries ──────────────────────────────────────────────────────────

const PROPOSALS_QUERY = `
  query GetProposals($first: Int!, $skip: Int!) {
    proposals(
      first: $first
      skip: $skip
      orderBy: createdAt
      orderDirection: desc
    ) {
      id
      proposalId
      proposer
      description
      startBlock
      endBlock
      status
      forVotes
      againstVotes
      abstainVotes
      createdAt
      transactions(first: 5, orderBy: blockTimestamp, orderDirection: desc) {
        id
        voter
        support
        weight
        reason
        blockTimestamp
      }
    }
  }
`

const PROPOSAL_BY_ID_QUERY = `
  query GetProposal($proposalId: String!) {
    proposals(where: { proposalId: $proposalId }) {
      id
      proposalId
      proposer
      description
      startBlock
      endBlock
      status
      forVotes
      againstVotes
      abstainVotes
      createdAt
      transactions(first: 20, orderBy: blockTimestamp, orderDirection: desc) {
        id
        voter
        support
        weight
        reason
        blockTimestamp
      }
    }
  }
`

const DELEGATES_QUERY = `
  query GetDelegates($delegator: String!) {
    delegations(
      where: { delegator: $delegator }
      orderBy: blockTimestamp
      orderDirection: desc
      first: 10
    ) {
      id
      delegator
      toDelegate
      blockTimestamp
    }
  }
`

// ─── Fetch helper ─────────────────────────────────────────────────────────────

async function fetchSubgraph<T>(
  query: string,
  variables: Record<string, unknown>
): Promise<T> {
  const response = await fetch(SUBGRAPH_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query, variables }),
    // Cache for 30 seconds (Next.js fetch cache)
    next: { revalidate: 30 },
  } as RequestInit)

  if (!response.ok) {
    throw new Error(`Subgraph request failed: ${response.statusText}`)
  }

  const json = await response.json()

  if (json.errors?.length) {
    throw new Error(`Subgraph error: ${json.errors[0].message}`)
  }

  return (json.data ?? {}) as T
}

// ─── Public API ───────────────────────────────────────────────────────────────

/**
 * Fetch paginated list of proposals from The Graph subgraph.
 * Falls back to empty array on error so UI doesn't break.
 */
export async function fetchProposals(
  first = 10,
  skip = 0
): Promise<SubgraphProposal[]> {
  try {
    const data = await fetchSubgraph<{ proposals: SubgraphProposal[] }>(
      PROPOSALS_QUERY,
      { first, skip }
    )
    return data?.proposals ?? []
  } catch (err) {
    console.error('[Subgraph] fetchProposals failed:', err)
    return []
  }
}

/**
 * Fetch a single proposal by its on-chain proposalId.
 */
export async function fetchProposalById(
  proposalId: string
): Promise<SubgraphProposal | null> {
  try {
    const data = await fetchSubgraph<{ proposals: SubgraphProposal[] }>(
      PROPOSAL_BY_ID_QUERY,
      { proposalId }
    )
    return data.proposals?.[0] ?? null
  } catch (err) {
    console.error('[Subgraph] fetchProposalById failed:', err)
    return null
  }
}

/**
 * Fetch delegation history for a given address.
 */
export async function fetchDelegations(
  delegator: string
): Promise<SubgraphDelegate[]> {
  try {
    const data = await fetchSubgraph<{ delegations: SubgraphDelegate[] }>(
      DELEGATES_QUERY,
      { delegator: delegator.toLowerCase() }
    )
    return data.delegations ?? []
  } catch (err) {
    console.error('[Subgraph] fetchDelegations failed:', err)
    return []
  }
}

// ─── Format helpers ───────────────────────────────────────────────────────────

/** Format raw vote weight (18 decimals) to human-readable */
export function formatVotes(raw: string): string {
  const n = BigInt(raw)
  const whole = n / BigInt(1e18)
  return whole.toLocaleString()
}

/** Map numeric support to label */
export function supportLabel(support: number): string {
  return support === 1 ? 'For' : support === 0 ? 'Against' : 'Abstain'
}

/** Map support to Tailwind color class */
export function supportColor(support: number): string {
  return support === 1
    ? 'text-green-400'
    : support === 0
    ? 'text-red-400'
    : 'text-gray-400'
}