'use client'

import { ConnectButton } from '@rainbow-me/rainbowkit'

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-5">
      <h1 className="text-4xl font-bold">
        Astra Protocol
      </h1>

      <p>DAO Governance dApp</p>

      <ConnectButton />
    </main>
  )
}