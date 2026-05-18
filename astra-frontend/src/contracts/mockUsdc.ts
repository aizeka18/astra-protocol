// MockUSDC — public mint (no auth), 6 decimals
export const MOCK_USDC_ADDRESS = '0xf8cc54cff031ff0c9ac71728c6f39b9ade7cb120' as const

export const mockUsdcAbi = [
  {
    inputs: [{ name: 'account', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    name: 'mint',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const
