import '@rainbow-me/rainbowkit/styles.css'

import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { arbitrumSepolia } from 'wagmi/chains'

export const config = getDefaultConfig({
  appName: 'Astra Protocol',
  projectId: '2f05ae7e6b5f4f8d9f6b123456789abc',
  chains: [arbitrumSepolia],
  ssr: true,
})