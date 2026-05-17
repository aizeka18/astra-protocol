export const GOVERNANCE_TOKEN_ADDRESS =
  '0xca6832828915de91f5cd1db830061f4a07fe22ef'

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
]