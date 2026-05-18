/**
 * src/contracts/governanceToken.ts
 * Fixed: removed duplicate comma that caused undefined entry in ABI array
 */

export const GOVERNANCE_TOKEN_ADDRESS =
  '0x6d4820Cf78b1Ca1A7ec9E1ccfB364e283e56F2ba'

export const governanceTokenAbi = [
  {
    inputs: [{ name: 'account', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'account', type: 'address' }],
    name: 'getVotes',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'account', type: 'address' }],
    name: 'delegates',
    outputs: [{ type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  // ✅ Fixed: removed duplicate comma before this entry
  {
    inputs: [{ name: 'delegatee', type: 'address' }],
    name: 'delegate',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const
