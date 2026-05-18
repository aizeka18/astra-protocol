'use client'

/**
 * app/proposals/page.tsx  (or embed as a section in page.tsx)
 *
 * Reads proposal data from The Graph subgraph — fulfills the requirement:
 * "at least one page/section must read from The Graph, not directly from the contract"
 *
 * Usage: add <ProposalsFromGraph /> anywhere in your main page.tsx
 */

import { useEffect, useState } from 'react'
import {
  fetchProposals,
  formatVotes,
  supportLabel,
  supportColor,
  type SubgraphProposal,
} from '../lib/subgraph'

// ─── Status badge ─────────────────────────────────────────────────────────────

const statusStyles: Record<string, string> = {
  Active: 'bg-green-500/20 text-green-300 border-green-500/40',
  Pending: 'bg-yellow-500/20 text-yellow-300 border-yellow-500/40',
  Succeeded: 'bg-purple-500/20 text-purple-300 border-purple-500/40',
  Defeated: 'bg-red-500/20 text-red-300 border-red-500/40',
  Queued: 'bg-orange-500/20 text-orange-300 border-orange-500/40',
  Executed: 'bg-blue-500/20 text-blue-300 border-blue-500/40',
  Canceled: 'bg-gray-500/20 text-gray-400 border-gray-500/40',
}

function StatusBadge({ status }: { status: string }) {
  const style = statusStyles[status] ?? 'bg-gray-700 text-gray-300 border-gray-600'
  return (
    <span className={`rounded-full border px-3 py-0.5 text-xs font-semibold ${style}`}>
      {status}
    </span>
  )
}

// ─── Skeleton loader ──────────────────────────────────────────────────────────

function ProposalSkeleton() {
  return (
    <div className="animate-pulse rounded-2xl border border-white/10 bg-white/5 p-6">
      <div className="mb-3 h-5 w-2/3 rounded bg-white/10" />
      <div className="mb-4 h-3 w-1/2 rounded bg-white/10" />
      <div className="flex gap-6">
        <div className="h-8 w-24 rounded bg-white/10" />
        <div className="h-8 w-24 rounded bg-white/10" />
      </div>
    </div>
  )
}

// ─── Proposal card ────────────────────────────────────────────────────────────

function ProposalCard({ proposal }: { proposal: SubgraphProposal }) {
  const forVotes = BigInt(proposal.forVotes)
  const againstVotes = BigInt(proposal.againstVotes)
  const total = forVotes + againstVotes
  const forPct = total > BigInt(0) ? Number((forVotes * BigInt(100)) / total) : 0

  const shortProposer = `${proposal.proposer.slice(0, 6)}…${proposal.proposer.slice(-4)}`
  const date = new Date(Number(proposal.createdAt) * 1000).toLocaleDateString()

  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-6 transition hover:border-white/20">
      {/* Header */}
      <div className="mb-3 flex items-start justify-between gap-3">
        <p className="font-mono text-xs text-gray-500">#{proposal.proposalId.slice(0, 8)}…</p>
        <StatusBadge status={proposal.status} />
      </div>

      {/* Description */}
      <p className="mb-1 text-base font-semibold leading-snug text-white">
        {proposal.description.length > 120
          ? proposal.description.slice(0, 120) + '…'
          : proposal.description}
      </p>

      <p className="mb-4 text-xs text-gray-500">
        By {shortProposer} · {date}
      </p>

      {/* Vote counts */}
      <div className="mb-3 flex gap-8 text-sm">
        <div>
          <span className="text-green-400 font-semibold">{formatVotes(proposal.forVotes)}</span>
          <span className="ml-1 text-gray-500">For</span>
        </div>
        <div>
          <span className="text-red-400 font-semibold">{formatVotes(proposal.againstVotes)}</span>
          <span className="ml-1 text-gray-500">Against</span>
        </div>
        <div>
          <span className="text-gray-400 font-semibold">{formatVotes(proposal.abstainVotes)}</span>
          <span className="ml-1 text-gray-500">Abstain</span>
        </div>
      </div>

      {/* Vote bar */}
      {total > BigInt(0) && (
        <div className="mb-4 h-1.5 w-full overflow-hidden rounded-full bg-white/10">
          <div
            className="h-full bg-gradient-to-r from-green-500 to-green-400 transition-all"
            style={{ width: `${forPct}%` }}
          />
        </div>
      )}

      {/* Recent votes from subgraph */}
      {proposal.transactions.length > 0 && (
        <div className="border-t border-white/10 pt-4">
          <p className="mb-2 text-xs font-semibold uppercase tracking-widest text-gray-500">
            Recent Votes (from subgraph)
          </p>
          <div className="flex flex-col gap-1.5">
            {proposal.transactions.slice(0, 3).map((vote) => (
              <div key={vote.id} className="flex items-center justify-between text-xs">
                <span className="font-mono text-gray-400">
                  {vote.voter.slice(0, 6)}…{vote.voter.slice(-4)}
                </span>
                <span className={`font-semibold ${supportColor(vote.support)}`}>
                  {supportLabel(vote.support)}
                </span>
                <span className="text-gray-500">{formatVotes(vote.weight)} votes</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Main component ───────────────────────────────────────────────────────────

export default function ProposalsFromGraph() {
  const [proposals, setProposals] = useState<SubgraphProposal[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [page, setPage] = useState(0)
  const PAGE_SIZE = 5

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    setError(null)

    fetchProposals(PAGE_SIZE, page * PAGE_SIZE)
      .then((data) => {
        if (!cancelled) {
          setProposals(data)
          setLoading(false)
        }
      })
      .catch((err) => {
        if (!cancelled) {
          setError('Failed to load from subgraph. Check your NEXT_PUBLIC_SUBGRAPH_URL.')
          setLoading(false)
        }
      })

    return () => { cancelled = true }
  }, [page])

  return (
    <section className="mt-16 w-full max-w-2xl">
      {/* Section header */}
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold">Proposals</h2>
          <p className="mt-1 text-xs text-gray-500">
            📡 Indexed data from{' '}
            <a
              href="https://thegraph.com"
              target="_blank"
              rel="noopener noreferrer"
              className="underline hover:text-gray-300"
            >
              The Graph
            </a>
          </p>
        </div>
      </div>

      {/* Error state */}
      {error && (
        <div className="mb-6 rounded-xl border border-yellow-500/40 bg-yellow-500/10 p-4 text-sm text-yellow-300">
          <p className="font-semibold">⚠️ Subgraph unavailable</p>
          <p className="mt-1 text-xs text-yellow-400/80">{error}</p>
          <p className="mt-2 text-xs text-gray-400">
            Set <code className="rounded bg-black/40 px-1">NEXT_PUBLIC_SUBGRAPH_URL</code> in your{' '}
            <code className="rounded bg-black/40 px-1">.env.local</code> file.
          </p>
        </div>
      )}

      {/* Loading skeletons */}
      {loading && (
        <div className="flex flex-col gap-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <ProposalSkeleton key={i} />
          ))}
        </div>
      )}

      {/* Proposals list */}
      {!loading && !error && proposals.length === 0 && (
        <div className="rounded-2xl border border-white/10 bg-white/5 p-8 text-center text-gray-500">
          <p>No proposals found in subgraph.</p>
          <p className="mt-1 text-xs">The subgraph may still be syncing.</p>
        </div>
      )}

      {!loading && proposals.length > 0 && (
        <>
          <div className="flex flex-col gap-4">
            {proposals.map((p) => (
              <ProposalCard key={p.id} proposal={p} />
            ))}
          </div>

          {/* Pagination */}
          <div className="mt-6 flex justify-center gap-3">
            <button
              onClick={() => setPage((p) => Math.max(0, p - 1))}
              disabled={page === 0}
              className="rounded-lg border border-white/20 px-4 py-2 text-sm text-gray-300 hover:border-white/40 disabled:opacity-30"
            >
              ← Prev
            </button>
            <span className="flex items-center text-sm text-gray-500">
              Page {page + 1}
            </span>
            <button
              onClick={() => setPage((p) => p + 1)}
              disabled={proposals.length < PAGE_SIZE}
              className="rounded-lg border border-white/20 px-4 py-2 text-sm text-gray-300 hover:border-white/40 disabled:opacity-30"
            >
              Next →
            </button>
          </div>
        </>
      )}
    </section>
  )
}
