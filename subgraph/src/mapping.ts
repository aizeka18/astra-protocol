import { BigInt, Bytes } from '@graphprotocol/graph-ts'

import {
  ProposalCreated,
  VoteCast,
  ProposalExecuted,
  ProposalQueued,
  ProposalCanceled,
} from '../generated/ProtocolGovernor/ProtocolGovernor'

import {
  DelegateChanged,
  DelegateVotesChanged,
  Transfer,
} from '../generated/GovernanceToken/GovernanceToken'

import {
  Deposit as DepositEvent,
  Withdraw as WithdrawEvent,
} from '../generated/YieldVault/YieldVault'

import {
  Proposal,
  Vote,
  Delegation,
  TokenHolder,
  VaultDeposit,
  VaultWithdrawal,
} from '../generated/schema'

// ─── Helpers ─────────────────────────────────────────────────────────────────

function logId(txHash: Bytes, logIndex: BigInt): string {
  return txHash.toHex() + '-' + logIndex.toString()
}

function loadOrCreateHolder(address: Bytes): TokenHolder {
  let id = address.toHex()
  let holder = TokenHolder.load(id)
  if (holder == null) {
    holder = new TokenHolder(id)
    holder.balance = BigInt.fromI32(0)
    holder.votingPower = BigInt.fromI32(0)
    holder.delegatedTo = Bytes.fromHexString('0x0000000000000000000000000000000000000000')
  }
  return holder as TokenHolder
}

// ─── ProtocolGovernor handlers ────────────────────────────────────────────────

export function handleProposalCreated(event: ProposalCreated): void {
  let proposal = new Proposal(event.params.proposalId.toString())
  proposal.proposalId   = event.params.proposalId
  proposal.proposer     = event.params.proposer
  proposal.description  = event.params.description
  proposal.startBlock   = event.params.voteStart
  proposal.endBlock     = event.params.voteEnd
  proposal.status       = 'Active'
  proposal.forVotes     = BigInt.fromI32(0)
  proposal.againstVotes = BigInt.fromI32(0)
  proposal.abstainVotes = BigInt.fromI32(0)
  proposal.createdAt    = event.block.timestamp
  proposal.save()
}

export function handleVoteCast(event: VoteCast): void {
  let vote = new Vote(logId(event.transaction.hash, event.logIndex))
  vote.proposal       = event.params.proposalId.toString()
  vote.voter          = event.params.voter
  vote.support        = event.params.support
  vote.weight         = event.params.weight
  vote.reason         = event.params.reason
  vote.blockTimestamp = event.block.timestamp
  vote.save()

  let proposal = Proposal.load(event.params.proposalId.toString())
  if (proposal != null) {
    if (event.params.support == 0) {
      proposal.againstVotes = proposal.againstVotes.plus(event.params.weight)
    } else if (event.params.support == 1) {
      proposal.forVotes = proposal.forVotes.plus(event.params.weight)
    } else {
      proposal.abstainVotes = proposal.abstainVotes.plus(event.params.weight)
    }
    proposal.save()
  }
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  let proposal = Proposal.load(event.params.proposalId.toString())
  if (proposal != null) {
    proposal.status = 'Executed'
    proposal.save()
  }
}

export function handleProposalQueued(event: ProposalQueued): void {
  let proposal = Proposal.load(event.params.proposalId.toString())
  if (proposal != null) {
    proposal.status = 'Queued'
    proposal.save()
  }
}

export function handleProposalCanceled(event: ProposalCanceled): void {
  let proposal = Proposal.load(event.params.proposalId.toString())
  if (proposal != null) {
    proposal.status = 'Canceled'
    proposal.save()
  }
}

// ─── GovernanceToken handlers ─────────────────────────────────────────────────

export function handleDelegateChanged(event: DelegateChanged): void {
  let delegation = new Delegation(logId(event.transaction.hash, event.logIndex))
  delegation.delegator      = event.params.delegator
  delegation.fromDelegate   = event.params.fromDelegate
  delegation.toDelegate     = event.params.toDelegate
  delegation.blockTimestamp = event.block.timestamp
  delegation.save()

  let holder = loadOrCreateHolder(event.params.delegator)
  holder.delegatedTo = event.params.toDelegate
  holder.save()
}

export function handleDelegateVotesChanged(event: DelegateVotesChanged): void {
  let holder = loadOrCreateHolder(event.params.delegate)
  holder.votingPower = event.params.newVotes
  holder.save()
}

export function handleTransfer(event: Transfer): void {
  let zero = '0x0000000000000000000000000000000000000000'

  if (event.params.from.toHex() != zero) {
    let sender = loadOrCreateHolder(event.params.from)
    sender.balance = sender.balance.minus(event.params.value)
    sender.save()
  }

  if (event.params.to.toHex() != zero) {
    let receiver = loadOrCreateHolder(event.params.to)
    receiver.balance = receiver.balance.plus(event.params.value)
    receiver.save()
  }
}

// ─── YieldVault handlers ──────────────────────────────────────────────────────

export function handleDeposit(event: DepositEvent): void {
  let deposit = new VaultDeposit(logId(event.transaction.hash, event.logIndex))
  deposit.sender         = event.params.sender
  deposit.owner          = event.params.owner
  deposit.assets         = event.params.assets
  deposit.shares         = event.params.shares
  deposit.blockTimestamp = event.block.timestamp
  deposit.save()
}

export function handleWithdraw(event: WithdrawEvent): void {
  let withdrawal = new VaultWithdrawal(logId(event.transaction.hash, event.logIndex))
  withdrawal.sender         = event.params.sender
  withdrawal.receiver       = event.params.receiver
  withdrawal.owner          = event.params.owner
  withdrawal.assets         = event.params.assets
  withdrawal.shares         = event.params.shares
  withdrawal.blockTimestamp = event.block.timestamp
  withdrawal.save()
}
