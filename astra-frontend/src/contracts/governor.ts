export const GOVERNOR_ADDRESS =
  '0x4f5f8c9e7b123456789abcdef123456789abcd'

export const governorAbi = [
  {
    inputs: [
      { name: 'proposalId', type: 'uint256' },
      { name: 'support', type: 'uint8' },
    ],
    name: 'castVote',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
]