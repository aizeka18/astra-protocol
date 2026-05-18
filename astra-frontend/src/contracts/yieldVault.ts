// ERC1967 proxy — YieldVault (ERC4626, underlying = MockUSDC 6 decimals)
export const YIELD_VAULT_ADDRESS = '0xeae2f21073290ec7cba7c6140352a805dd9678ce' as const

export const yieldVaultAbi = [
  {
    inputs: [],
    name: 'totalAssets',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'totalSupply',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'account', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const
