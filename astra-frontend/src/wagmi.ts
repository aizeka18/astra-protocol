import { createConfig, http } from 'wagmi'
import { arbitrumSepolia } from 'wagmi/chains'
import { metaMask, walletConnect } from 'wagmi/connectors'

const wcProjectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID

export const config = createConfig({
  chains: [arbitrumSepolia],
  connectors: [
    metaMask(),
    ...(wcProjectId ? [walletConnect({ projectId: wcProjectId })] : []),
  ],
  transports: {
    [arbitrumSepolia.id]: http(),
  },
  ssr: true,
})
