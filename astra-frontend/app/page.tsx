'use client'

import { useState, useEffect } from 'react'
import {
  useAccount,
  useBalance,
  useChainId,
  useConnect,
  useDisconnect,
  usePublicClient,
  useReadContract,
  useSwitchChain,
  useWriteContract,
} from 'wagmi'
import { decodeEventLog, formatEther, formatUnits } from 'viem'

import {
  GOVERNANCE_TOKEN_ADDRESS,
  governanceTokenAbi,
} from '../src/contracts/governanceToken'
import { GOVERNOR_ADDRESS, governorAbi } from '../src/contracts/governor'
import { YIELD_VAULT_ADDRESS, yieldVaultAbi } from '../src/contracts/yieldVault'
import { MOCK_USDC_ADDRESS, mockUsdcAbi } from '../src/contracts/mockUsdc'
import { proposals as staticProposals } from '../src/data/proposals'
import ProposalsFromGraph from '../src/components/ProposalsFromGraph'

// ─── Types ────────────────────────────────────────────────────────────────────

type TxStatus = 'idle' | 'pending' | 'confirming' | 'success' | 'error'

interface TxState {
  status: TxStatus
  message: string
  hash?: `0x${string}`
}

interface ProposalEntry {
  id: string
  title: string
  description: string
}

// ─── Constants ────────────────────────────────────────────────────────────────

const ARBITRUM_SEPOLIA_ID = 421614

const PROPOSAL_STATES = [
  'Pending',
  'Active',
  'Canceled',
  'Defeated',
  'Succeeded',
  'Queued',
  'Expired',
  'Executed',
]

// ─── Error parser ─────────────────────────────────────────────────────────────

function parseError(error: unknown): string {
  if (!error) return 'Unknown error'
  const msg = (error as Error).message ?? String(error)
  const lower = msg.toLowerCase()

  if (
    lower.includes('user rejected') ||
    lower.includes('action_rejected') ||
    lower.includes('request rejected')
  )
    return '❌ Transaction rejected by user.'

  if (lower.includes('insufficient funds'))
    return '❌ Insufficient ETH balance to pay gas fees.'

  if (
    lower.includes('governorinsufficientproposervotes') ||
    lower.includes('proposer votes below')
  )
    return '❌ You need ≥ 10,000 AGT voting power. Delegate your tokens to self first.'

  if (
    lower.includes('governoralreadycastvote') ||
    lower.includes('already voted') ||
    lower.includes('voter already voted')
  )
    return '❌ You have already voted on this proposal.'

  if (
    lower.includes('governorunexpectedproposalstate') ||
    lower.includes('vote not currently active') ||
    lower.includes('not active')
  )
    return '❌ Proposal is not currently Active for voting.'

  if (
    lower.includes('governornonexistentproposal') ||
    lower.includes('unknown proposal id')
  )
    return '❌ This proposal does not exist on chain.'

  if (lower.includes('execution reverted'))
    return '❌ Transaction reverted. Check your voting power and proposal state.'

  if (msg.length > 120) return `❌ Transaction failed: ${msg.slice(0, 100)}…`
  return `❌ ${msg}`
}

// ─── Toast ────────────────────────────────────────────────────────────────────

function Toast({ tx, onClose }: { tx: TxState; onClose: () => void }) {
  if (tx.status === 'idle') return null

  const colors: Record<TxStatus, string> = {
    idle: '',
    pending: 'border-yellow-500 bg-yellow-500/10 text-yellow-300',
    confirming: 'border-blue-500 bg-blue-500/10 text-blue-300',
    success: 'border-green-500 bg-green-500/10 text-green-300',
    error: 'border-red-500 bg-red-500/10 text-red-300',
  }

  return (
    <div
      className={`fixed bottom-6 right-6 z-50 max-w-sm rounded-xl border p-4 shadow-2xl ${colors[tx.status]}`}
    >
      <div className="flex items-start justify-between gap-3">
        <p className="text-sm font-medium leading-relaxed">{tx.message}</p>
        <button
          onClick={onClose}
          className="mt-0.5 shrink-0 text-white/60 hover:text-white"
        >
          ✕
        </button>
      </div>
      {tx.hash && (
        <a
          href={`https://sepolia.arbiscan.io/tx/${tx.hash}`}
          target="_blank"
          rel="noopener noreferrer"
          className="mt-2 block text-xs underline opacity-70 hover:opacity-100"
        >
          View on Arbiscan ↗
        </a>
      )}
    </div>
  )
}

// ─── Status badge colors ──────────────────────────────────────────────────────

const statusColors: Record<string, string> = {
  Active: 'bg-green-500 text-black',
  Pending: 'bg-yellow-500 text-black',
  Succeeded: 'bg-purple-500 text-white',
  Defeated: 'bg-red-500 text-white',
  Queued: 'bg-orange-500 text-black',
  Executed: 'bg-blue-500 text-white',
  Canceled: 'bg-gray-600 text-white',
  Expired: 'bg-gray-600 text-white',
}

// ─── ProposalRow — reads its own on-chain state ───────────────────────────────

interface ProposalRowProps {
  proposal: ProposalEntry
  address?: `0x${string}`
  isVoting: boolean
  isConnected: boolean
  wrongNetwork: boolean
  onVote: (proposalId: string, support: number, title: string) => void
}

function ProposalRow({
  proposal,
  address,
  isVoting,
  isConnected,
  wrongNetwork,
  onVote,
}: ProposalRowProps) {
  const idBn = BigInt(proposal.id)

  const { data: stateData } = useReadContract({
    address: GOVERNOR_ADDRESS,
    abi: governorAbi,
    functionName: 'state',
    args: [idBn],
    query: { retry: false, refetchInterval: 5_000 },
  })

  const { data: votesData } = useReadContract({
    address: GOVERNOR_ADDRESS,
    abi: governorAbi,
    functionName: 'proposalVotes',
    args: [idBn],
    query: { retry: false, refetchInterval: 5_000 },
  })

  const { data: alreadyVoted } = useReadContract({
    address: GOVERNOR_ADDRESS,
    abi: governorAbi,
    functionName: 'hasVoted',
    args: address ? [idBn, address] : undefined,
    query: { enabled: !!address, retry: false, refetchInterval: 5_000 },
  })

  const status =
    stateData !== undefined
      ? (PROPOSAL_STATES[Number(stateData)] ?? 'Unknown')
      : '…'

  const canVote =
    status === 'Active' && !alreadyVoted && isConnected && !wrongNetwork

  const voteDisabledReason: string | undefined =
    !isConnected
      ? 'Connect your wallet to vote'
      : wrongNetwork
      ? 'Switch to Arbitrum Sepolia to vote'
      : alreadyVoted
      ? 'You have already voted on this proposal'
      : status !== 'Active'
      ? `Voting not available — proposal is ${status}`
      : undefined

  const votes = votesData as
    | readonly [bigint, bigint, bigint]
    | undefined
  const forVotes = votes ? Number(formatEther(votes[1])) : 0
  const againstVotes = votes ? Number(formatEther(votes[0])) : 0
  const totalVotes = forVotes + againstVotes

  return (
    <div className="rounded-2xl border border-white/20 bg-white/5 p-8">
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0">
          <h3 className="text-2xl font-semibold">{proposal.title}</h3>
          <p className="mt-0.5 font-mono text-xs text-gray-500">
            {proposal.id.slice(0, 14)}…{proposal.id.slice(-6)}
          </p>
        </div>
        <span
          className={`shrink-0 rounded-full px-3 py-1 text-xs font-bold ${
            statusColors[status] ?? 'bg-gray-600 text-white'
          }`}
        >
          {status}
        </span>
      </div>

      <p className="mt-3 text-sm text-gray-400">{proposal.description}</p>

      {votes && (
        <div className="mt-5 flex gap-10">
          <div>
            <p className="text-xs uppercase tracking-widest text-gray-500">
              Votes For
            </p>
            <p className="mt-1 text-lg font-semibold text-green-400">
              {forVotes.toLocaleString(undefined, { maximumFractionDigits: 0 })}
            </p>
          </div>
          <div>
            <p className="text-xs uppercase tracking-widest text-gray-500">
              Votes Against
            </p>
            <p className="mt-1 text-lg font-semibold text-red-400">
              {againstVotes.toLocaleString(undefined, {
                maximumFractionDigits: 0,
              })}
            </p>
          </div>
        </div>
      )}

      {totalVotes > 0 && (
        <div className="mt-4 h-2 w-full overflow-hidden rounded-full bg-white/10">
          <div
            className="h-full bg-green-500 transition-all"
            style={{ width: `${(forVotes / totalVotes) * 100}%` }}
          />
        </div>
      )}

      {alreadyVoted && (
        <p className="mt-4 text-xs text-blue-400">
          ✓ You have already voted on this proposal.
        </p>
      )}

      <div className="mt-6 flex flex-wrap gap-3">
        <button
          onClick={() => onVote(proposal.id, 1, proposal.title)}
          disabled={!canVote || isVoting}
          title={voteDisabledReason}
          className="rounded-xl bg-green-500 px-5 py-2.5 text-sm font-bold text-black transition hover:bg-green-400 disabled:cursor-not-allowed disabled:opacity-40"
        >
          {isVoting ? '⏳…' : '✅ Vote For'}
        </button>
        <button
          onClick={() => onVote(proposal.id, 0, proposal.title)}
          disabled={!canVote || isVoting}
          title={voteDisabledReason}
          className="rounded-xl bg-red-500 px-5 py-2.5 text-sm font-bold text-white transition hover:bg-red-400 disabled:cursor-not-allowed disabled:opacity-40"
        >
          {isVoting ? '⏳…' : '❌ Vote Against'}
        </button>
        <button
          onClick={() => onVote(proposal.id, 2, proposal.title)}
          disabled={!canVote || isVoting}
          title={voteDisabledReason}
          className="rounded-xl bg-gray-600 px-5 py-2.5 text-sm font-bold text-white transition hover:bg-gray-500 disabled:cursor-not-allowed disabled:opacity-40"
        >
          {isVoting ? '⏳…' : '🤐 Abstain'}
        </button>
      </div>

      {voteDisabledReason && status !== '…' && (
        <p className="mt-3 text-xs text-gray-500">
          ℹ️ {voteDisabledReason}.
        </p>
      )}
    </div>
  )
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function Home() {
  const { address, isConnected } = useAccount()
  const chainId = useChainId()
  const { switchChain, isPending: isSwitching } = useSwitchChain()
  const { connectors, connect, error: connectError } = useConnect()
  const { disconnect } = useDisconnect()
  const { writeContractAsync } = useWriteContract()
  const publicClient = usePublicClient()

  const metaMaskConnector =
    connectors.find((c) => c.id === 'metaMask') ?? connectors[0]
  const walletConnectConnector = connectors.find(
    (c) => c.id === 'walletConnect',
  )

  const wrongNetwork = isConnected && chainId !== ARBITRUM_SEPOLIA_ID

  const [tx, setTx] = useState<TxState>({ status: 'idle', message: '' })
  const [votingProposalId, setVotingProposalId] = useState<string | null>(null)
  const [sessionProposals, setSessionProposals] = useState<ProposalEntry[]>([])

  // Persist created proposals so they survive page refreshes
  useEffect(() => {
    try {
      const stored = localStorage.getItem('astra:proposals')
      if (stored) setSessionProposals(JSON.parse(stored))
    } catch { /* ignore */ }
  }, [])

  useEffect(() => {
    localStorage.setItem('astra:proposals', JSON.stringify(sessionProposals))
  }, [sessionProposals])

  // ── Reads ──────────────────────────────────────────────────────────────────

  const { data: ethBalance } = useBalance({
    address,
    query: { enabled: !!address },
  })

  const { data: tokenBalance } = useReadContract({
    address: GOVERNANCE_TOKEN_ADDRESS,
    abi: governanceTokenAbi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  })

  const { data: votingPower } = useReadContract({
    address: GOVERNANCE_TOKEN_ADDRESS,
    abi: governanceTokenAbi,
    functionName: 'getVotes',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  })

  const { data: delegate } = useReadContract({
    address: GOVERNANCE_TOKEN_ADDRESS,
    abi: governanceTokenAbi,
    functionName: 'delegates',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  })

  // Protocol-specific state: Yield Vault TVL and user position
  const { data: vaultTotalAssets } = useReadContract({
    address: YIELD_VAULT_ADDRESS,
    abi: yieldVaultAbi,
    functionName: 'totalAssets',
    query: { refetchInterval: 15_000 },
  })

  const { data: vaultShares } = useReadContract({
    address: YIELD_VAULT_ADDRESS,
    abi: yieldVaultAbi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  })

  const { data: usdcBalance, refetch: refetchUsdc } = useReadContract({
    address: MOCK_USDC_ADDRESS,
    abi: mockUsdcAbi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  })

  // ── Helpers ────────────────────────────────────────────────────────────────

  // Merge static + session, dedup by id so static proposals are never duplicated
  const allProposals: ProposalEntry[] = [
    ...staticProposals,
    ...sessionProposals.filter(
      (s) => !staticProposals.some((p) => p.id === s.id),
    ),
  ]

  const clearSessionProposals = () => {
    setSessionProposals([])
    localStorage.removeItem('astra:proposals')
  }

  const formatTokens = (val: unknown) =>
    !val
      ? '0'
      : Number(formatEther(val as bigint)).toLocaleString(undefined, {
          maximumFractionDigits: 2,
        })

  const formatUsdc = (val: unknown) =>
    !val
      ? '0.00'
      : Number(formatUnits(val as bigint, 6)).toLocaleString(undefined, {
          maximumFractionDigits: 2,
        })

  const shortAddr = (addr: string) => `${addr.slice(0, 6)}…${addr.slice(-4)}`

  const isSelfDelegate =
    !!delegate &&
    !!address &&
    (delegate as string).toLowerCase() === address.toLowerCase()

  // ── Guards ─────────────────────────────────────────────────────────────────

  const guard = (): boolean => {
    if (!address) {
      setTx({ status: 'error', message: '⚠️ Please connect your wallet first.' })
      return false
    }
    if (wrongNetwork) {
      setTx({
        status: 'error',
        message: '⚠️ Please switch to Arbitrum Sepolia first.',
      })
      return false
    }
    return true
  }

  // ── Write: delegate ────────────────────────────────────────────────────────

  const handleDelegate = async () => {
    if (!guard()) return
    try {
      setTx({ status: 'pending', message: '⏳ Delegating votes to self… Confirm in wallet.' })
      const hash = await writeContractAsync({
        address: GOVERNANCE_TOKEN_ADDRESS,
        abi: governanceTokenAbi,
        functionName: 'delegate',
        args: [address!],
      })
      setTx({ status: 'success', message: '✅ Votes delegated to self!', hash })
    } catch (error) {
      setTx({ status: 'error', message: parseError(error) })
    }
  }

  // ── Write: create proposal ─────────────────────────────────────────────────

  const handleCreateProposal = async () => {
    if (!guard()) return

    const power = votingPower ? BigInt(votingPower as bigint) : BigInt(0)
    if (power < BigInt('10000000000000000000000')) {
      setTx({
        status: 'error',
        message: '❌ You need ≥ 10,000 AGT voting power. Delegate your tokens first.',
      })
      return
    }

    // Unique description so the hash is different each time
    const description = `Treasury allocation — ${new Date().toISOString()}`

    try {
      setTx({ status: 'pending', message: '⏳ Creating proposal… Confirm in wallet.' })

      const hash = await writeContractAsync({
        address: GOVERNOR_ADDRESS,
        abi: governorAbi,
        functionName: 'propose',
        args: [
          [GOVERNANCE_TOKEN_ADDRESS],
          [BigInt(0)],
          ['0x'],          // empty calldata — no-op target call
          description,
        ],
      })

      setTx({ status: 'confirming', message: '⏳ Waiting for confirmation…', hash })

      let newId: string | null = null
      if (publicClient) {
        const receipt = await publicClient.waitForTransactionReceipt({ hash })
        for (const log of receipt.logs) {
          if (log.address.toLowerCase() !== GOVERNOR_ADDRESS.toLowerCase())
            continue
          try {
            const event = decodeEventLog({
              abi: governorAbi,
              data: log.data,
              topics: log.topics,
              eventName: 'ProposalCreated',
            })
            newId = String(
              (event.args as { proposalId: bigint }).proposalId,
            )
          } catch {
            // not a ProposalCreated log
          }
        }
      }

      if (newId) {
        setSessionProposals((prev) => [
          ...prev,
          { id: newId!, title: 'Treasury Allocation', description },
        ])
        setTx({
          status: 'success',
          message: '✅ Proposal created! Wait 1 block, then vote.',
          hash,
        })
      } else {
        setTx({ status: 'success', message: '✅ Proposal created!', hash })
      }
    } catch (error) {
      setTx({ status: 'error', message: parseError(error) })
    }
  }

  // ── Write: vote ────────────────────────────────────────────────────────────

  const handleVote = async (
    proposalId: string,
    support: number,
    proposalTitle: string,
  ) => {
    if (!guard()) return

    const power = votingPower ? BigInt(votingPower as bigint) : BigInt(0)
    if (power === BigInt(0)) {
      setTx({
        status: 'error',
        message: '❌ No voting power. Delegate your tokens to self first.',
      })
      return
    }

    const supportLabel =
      support === 1 ? 'For' : support === 0 ? 'Against' : 'Abstain'

    try {
      setVotingProposalId(proposalId)
      setTx({
        status: 'pending',
        message: `⏳ Voting "${supportLabel}" on "${proposalTitle}"… Confirm in wallet.`,
      })

      const hash = await writeContractAsync({
        address: GOVERNOR_ADDRESS,
        abi: governorAbi,
        functionName: 'castVote',
        args: [BigInt(proposalId), support],
      })

      setTx({
        status: 'success',
        message: `✅ Vote "${supportLabel}" cast on "${proposalTitle}"!`,
        hash,
      })
    } catch (error) {
      setTx({ status: 'error', message: parseError(error) })
    } finally {
      setVotingProposalId(null)
    }
  }

  // ── Write: mint mUSDC (test faucet) ────────────────────────────────────────

  const handleMintUsdc = async () => {
    if (!guard()) return
    try {
      setTx({ status: 'pending', message: '⏳ Minting 1,000 mUSDC… Confirm in wallet.' })
      const hash = await writeContractAsync({
        address: MOCK_USDC_ADDRESS,
        abi: mockUsdcAbi,
        functionName: 'mint',
        args: [address!, BigInt('1000000000')], // 1,000 × 10^6
      })
      setTx({ status: 'success', message: '✅ 1,000 mUSDC minted!', hash })
      refetchUsdc()
    } catch (error) {
      setTx({ status: 'error', message: parseError(error) })
    }
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  return (
    <main className="flex min-h-screen flex-col items-center bg-black px-6 py-12 text-white">
      <Toast tx={tx} onClose={() => setTx({ status: 'idle', message: '' })} />

      <h1 className="text-6xl font-bold">Astra Protocol</h1>
      <p className="mt-4 text-2xl text-gray-400">DAO Governance Dashboard</p>

      {/* ── Wallet connect ── */}
      <div className="mt-6 flex flex-wrap justify-center gap-3">
        {!isConnected ? (
          <>
            <button
              onClick={() => connect({ connector: metaMaskConnector })}
              className="rounded-xl bg-white px-5 py-3 font-bold text-black hover:bg-gray-100"
            >
              Connect MetaMask
            </button>
            {walletConnectConnector && (
              <button
                onClick={() => connect({ connector: walletConnectConnector })}
                className="rounded-xl border border-white/30 px-5 py-3 font-bold text-white hover:bg-white/10"
              >
                WalletConnect
              </button>
            )}
          </>
        ) : (
          <button
            onClick={() => disconnect()}
            className="rounded-xl bg-white px-5 py-3 font-bold text-black hover:bg-gray-100"
          >
            Disconnect ({shortAddr(address!)})
          </button>
        )}
        {connectError && (
          <p className="w-full text-center text-sm text-red-400">
            ⚠️ Wallet connection failed. Is MetaMask installed?
          </p>
        )}
      </div>

      {/* ── Wrong network banner ── */}
      {wrongNetwork && (
        <div className="mt-6 w-full max-w-md rounded-xl border border-red-500 bg-red-500/10 p-5 text-center">
          <p className="text-lg font-bold text-red-400">⚠️ Wrong Network</p>
          <p className="mt-1 text-sm text-gray-300">
            This dApp requires{' '}
            <strong>Arbitrum Sepolia</strong> (chainId 421614). You are on
            chain {chainId}.
          </p>
          <button
            onClick={() => switchChain({ chainId: ARBITRUM_SEPOLIA_ID })}
            disabled={isSwitching}
            className="mt-4 rounded-lg bg-red-500 px-5 py-2 font-semibold text-white disabled:opacity-50"
          >
            {isSwitching ? 'Switching…' : 'Switch to Arbitrum Sepolia'}
          </button>
        </div>
      )}

      {/* ── Wallet info card ── */}
      {address && (
        <div className="mt-10 w-full max-w-md rounded-2xl border border-white/20 bg-white/5 p-8">
          <div className="mb-5">
            <p className="text-xs uppercase tracking-widest text-gray-500">
              Wallet
            </p>
            <p className="mt-1 break-all font-mono text-sm">{address}</p>
          </div>

          <div className="mb-5">
            <p className="text-xs uppercase tracking-widest text-gray-500">
              ETH Balance
            </p>
            <p className="mt-1 text-xl font-semibold">
              {ethBalance ? Number(ethBalance.formatted).toFixed(4) : '0'} ETH
            </p>
          </div>

          <div className="mb-5">
            <p className="text-xs uppercase tracking-widest text-gray-500">
              AGT Token Balance
            </p>
            <p className="mt-1 text-2xl font-semibold">
              {formatTokens(tokenBalance)} AGT
            </p>
          </div>

          <div className="mb-5">
            <p className="text-xs uppercase tracking-widest text-gray-500">
              Voting Power
            </p>
            <p className="mt-1 text-2xl font-semibold">
              {formatTokens(votingPower)} Votes
            </p>
            {votingPower !== undefined &&
              BigInt(votingPower as bigint) === BigInt(0) &&
              tokenBalance !== undefined &&
              BigInt(tokenBalance as bigint) > BigInt(0) && (
                <p className="mt-1 text-xs text-yellow-400">
                  ⚠️ You have tokens but no voting power. Click "Delegate Votes to Self".
                </p>
              )}
          </div>

          <div className="mb-6">
            <p className="text-xs uppercase tracking-widest text-gray-500">
              Delegate
            </p>
            <p className="mt-1 font-mono text-sm">
              {delegate
                ? isSelfDelegate
                  ? `${shortAddr(delegate as string)} (self)`
                  : shortAddr(delegate as string)
                : '—'}
            </p>
          </div>

          {/* Protocol-specific state: Yield Vault */}
          <div className="mb-6 rounded-xl border border-white/10 bg-white/5 p-4">
            <p className="mb-3 text-xs uppercase tracking-widest text-gray-500">
              Yield Vault · Protocol State
            </p>
            <div className="grid grid-cols-3 gap-3 text-sm">
              <div>
                <p className="text-xs text-gray-500">TVL</p>
                <p className="mt-0.5 font-semibold text-blue-300">
                  {formatUsdc(vaultTotalAssets)} mUSDC
                </p>
              </div>
              <div>
                <p className="text-xs text-gray-500">Your Shares</p>
                <p className="mt-0.5 font-semibold text-purple-300">
                  {formatUsdc(vaultShares)} avTKN
                </p>
              </div>
              <div>
                <p className="text-xs text-gray-500">mUSDC Balance</p>
                <p className="mt-0.5 font-semibold text-teal-300">
                  {formatUsdc(usdcBalance)} mUSDC
                </p>
              </div>
            </div>
          </div>

          {/* Write tx 1: delegate */}
          <button
            onClick={handleDelegate}
            disabled={tx.status === 'pending' || wrongNetwork}
            className="w-full rounded-xl bg-white px-4 py-3 text-lg font-bold text-black transition hover:bg-gray-200 disabled:opacity-50"
          >
            Delegate Votes to Self
          </button>

          {/* Write tx 2: create proposal */}
          <button
            onClick={handleCreateProposal}
            disabled={tx.status === 'pending' || wrongNetwork}
            className="mt-3 w-full rounded-xl bg-blue-600 px-4 py-3 text-lg font-bold text-white transition hover:bg-blue-500 disabled:opacity-50"
          >
            Create Proposal
          </button>

          {/* Write tx 3: mint mUSDC faucet */}
          <button
            onClick={handleMintUsdc}
            disabled={tx.status === 'pending' || wrongNetwork}
            className="mt-3 w-full rounded-xl bg-teal-700 px-4 py-3 text-lg font-bold text-white transition hover:bg-teal-600 disabled:opacity-50"
          >
            Mint 1,000 mUSDC (Test Faucet)
          </button>
        </div>
      )}

      {/* ── On-chain governance proposals ── */}
      <div className="mt-16 w-full max-w-2xl">
        <div className="mb-2 flex items-center justify-between gap-4">
          <h2 className="text-4xl font-bold">Governance Proposals</h2>
          {sessionProposals.length > 0 && (
            <button
              onClick={clearSessionProposals}
              className="rounded-lg border border-white/20 px-3 py-1.5 text-xs text-gray-400 hover:border-red-500/50 hover:text-red-400"
            >
              Clear created
            </button>
          )}
        </div>
        <p className="mb-8 text-sm text-gray-500">
          Status read live from the Governor contract. Vote buttons are enabled
          only when a proposal is Active and you have not already voted.
        </p>
        <div className="flex flex-col gap-6">
          {allProposals.map((proposal) => (
            <ProposalRow
              key={proposal.id}
              proposal={proposal}
              address={address}
              isVoting={votingProposalId === proposal.id}
              isConnected={isConnected}
              wrongNetwork={wrongNetwork}
              onVote={handleVote}
            />
          ))}
        </div>
      </div>

      {/* ── Subgraph section ── */}
      <ProposalsFromGraph />
    </main>
  )
}
