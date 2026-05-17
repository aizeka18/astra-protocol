'use client'

import { ConnectButton } from '@rainbow-me/rainbowkit'
import { useAccount, useReadContract } from 'wagmi'
import { formatEther } from 'viem'

import {
  GOVERNANCE_TOKEN_ADDRESS,
  governanceTokenAbi,
} from '../src/contracts/governanceToken'

export default function Home() {
  const { address } = useAccount()

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

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-6 bg-black text-white">
      <h1 className="text-5xl font-bold">
        Astra Protocol
      </h1>

      <p className="text-xl">
        DAO Governance Dashboard
      </p>

      <ConnectButton />

      {address && (
        <div className="mt-6 flex flex-col gap-4 rounded-xl border border-white/20 p-6 w-[400px]">
          <div>
            <p className="text-gray-400">Wallet</p>
            <p>{address}</p>
          </div>

          <div>
            <p className="text-gray-400">Token Balance</p>
            <p>
              {balance
                ? Number(formatEther(balance as bigint)).toFixed(2)
                : '0'} AGT
            </p>
          </div>

          <div>
            <p className="text-gray-400">Voting Power</p>
            <p>
              {votingPower
                ? Number(formatEther(votingPower as bigint)).toFixed(2)
                : '0'} Votes
            </p>
          </div>

          <div>
            <p className="text-gray-400">Delegate</p>
            <p>{delegate as string}</p>
          </div>
        </div>
      )}
    </main>
  )
}