import '@rainbow-me/rainbowkit/styles.css'

import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { arbitrumSepolia } from 'wagmi/chains'

export const config = getDefaultConfig({
  appName: 'Astra Protocol',
  projectId: '5fd754bef40afc7d968701938ebc68c9',
  chains: [arbitrumSepolia],
  ssr: true,
})