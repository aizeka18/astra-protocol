'use client'

import { ConnectButton } from '@rainbow-me/rainbowkit'
import {
  useAccount,
  useReadContract,
  useWriteContract,
} from 'wagmi'

import { formatEther } from 'viem'

import {
  GOVERNANCE_TOKEN_ADDRESS,
  governanceTokenAbi,
} from '../src/contracts/governanceToken'

import { proposals } from '../src/data/proposals'

export default function Home() {
  const { address } = useAccount()

  const { writeContract } = useWriteContract()

  const { data: balance } = useReadContract({
    address: GOVERNANCE_TOKEN_ADDRESS,
    abi: governanceTokenAbi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  })

  const { data: votingPower } = useReadContract({
    address: GOVERNANCE_TOKEN_ADDRESS,
    abi: governanceTokenAbi,
    functionName: 'getVotes',
    args: address ? [address] : undefined,
  })

  const { data: delegate } = useReadContract({
    address: GOVERNANCE_TOKEN_ADDRESS,
    abi: governanceTokenAbi,
    functionName: 'delegates',
    args: address ? [address] : undefined,
  })

  const handleDelegate = async () => {
    if (!address) return

    writeContract({
      address: GOVERNANCE_TOKEN_ADDRESS,
      abi: governanceTokenAbi,
      functionName: 'delegate',
      args: [address],
    })
  }

  return (
    <main className="flex min-h-screen flex-col items-center bg-black px-6 py-12 text-white">
      <h1 className="text-6xl font-bold">
        Astra Protocol
      </h1>

      <p className="mt-4 text-2xl">
        DAO Governance Dashboard
      </p>

      <div className="mt-6">
        <ConnectButton />
      </div>

      {address && (
        <div className="mt-10 w-[450px] rounded-2xl border border-white/20 p-8">
          <div className="mb-6">
            <p className="text-gray-400">Wallet</p>
            <p className="break-all text-lg">
              {address}
            </p>
          </div>

          <div className="mb-6">
            <p className="text-gray-400">Token Balance</p>
            <p className="text-2xl font-semibold">
              {balance
                ? Number(
                    formatEther(balance as bigint)
                  ).toFixed(2)
                : '0'}{' '}
              AGT
            </p>
          </div>

          <div className="mb-6">
            <p className="text-gray-400">Voting Power</p>
            <p className="text-2xl font-semibold">
              {votingPower
                ? Number(
                    formatEther(votingPower as bigint)
                  ).toFixed(2)
                : '0'}{' '}
              Votes
            </p>
          </div>

          <div className="mb-8">
            <p className="text-gray-400">Delegate</p>
            <p className="break-all">
              {delegate as string}
            </p>
          </div>

          <button
            onClick={handleDelegate}
            className="w-full rounded-xl bg-white px-4 py-3 text-lg font-bold text-black transition hover:bg-gray-300"
          >
            Delegate Votes
          </button>
        </div>
      )}

      <div className="mt-16 w-full max-w-4xl">
        <h2 className="mb-8 text-4xl font-bold">
          Governance Proposals
        </h2>

        <div className="flex flex-col gap-6">
          {proposals.map((proposal) => (
            <div
              key={proposal.id}
              className="rounded-2xl border border-white/20 p-8"
            >
              <div className="flex items-center justify-between">
                <h3 className="text-3xl font-semibold">
                  {proposal.title}
                </h3>

                <span
                  className={`rounded-full px-4 py-2 text-sm font-bold ${
                    proposal.status === 'Active'
                      ? 'bg-green-500 text-black'
                      : proposal.status === 'Pending'
                      ? 'bg-yellow-500 text-black'
                      : 'bg-blue-500 text-black'
                  }`}
                >
                  {proposal.status}
                </span>
              </div>

              <p className="mt-4 text-lg text-gray-400">
                {proposal.description}
              </p>

              <div className="mt-6 flex gap-12">
                <div>
                  <p className="text-gray-400">
                    Votes For
                  </p>

                  <p className="text-xl font-semibold">
                    {proposal.votesFor}
                  </p>
                </div>

                <div>
                  <p className="text-gray-400">
                    Votes Against
                  </p>

                  <p className="text-xl font-semibold">
                    {proposal.votesAgainst}
                  </p>
                </div>
              </div>

              <div className="mt-8 flex gap-4">
                <button className="rounded-xl bg-green-500 px-5 py-3 font-bold text-black transition hover:bg-green-400">
                  Vote For
                </button>

                <button className="rounded-xl bg-red-500 px-5 py-3 font-bold text-white transition hover:bg-red-400">
                  Vote Against
                </button>

                <button className="rounded-xl bg-gray-600 px-5 py-3 font-bold text-white transition hover:bg-gray-500">
                  Abstain
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </main>
  )
}