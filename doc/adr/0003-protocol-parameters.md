# 3. protocol-parameters

Date: 2026-09-08

## Status

Draft

## Context

We need to define a list of the protocol paramters that are governable. It means that
they affect how the protocol works, should be defined equally for all the nodes,
can be changed without modification of the node implementations across the era-boundaries,
are defined by the governance procedure.

There are multiple places where this parameters should be supported:

- [Ledger][ledger-repo] — definitions and on-chain structure, api for access, specification,
- [Consensus][consensus-repo] - to be used in the ledger codebase in the consensus,
- [CIP-140][cip-140] — the implementation of ledger as a source of truth for the node developers,
- [Peras design document][peras-design] — as a source of truth for the implementaiton and code audit,
- [Cardano constitution][cardano-constitution] — the parameters must be listed together with the guardrails for their values.

Most of the parameters are defined by the CIP and design, but during the implementation
we have uncovered multiple new ones or ones that can't be actually changed.

List of the parameters proposed for consideration in various places, they should not:

1. $U$ Round length — The duration of each voting round.
1. $L$ (`ppPerasMinCandidateBlockAge`) Block selection offset  - The minimum age of a candidate block for being voted upon.
1. $A$ (`ppPerasCertMaxRounds`) Certificate expiration  - The maximum age for a certificate to be included in a block.
1. $R$ Chain ignorance period - The number of rounds for which to ignore certificates after entering a cool-down period.
1. $K$ Cool-down period - The minimum number of rounds to wait before voting again after a cool-down period starts.
1. $B$ (`ppPerasExtraChainWeight`) Certification boost - The extra chain weight that a certificate gives to a block.
1. $\tau$ Quorum size - The number of votes required to create a certificate.
1. $n$ (`ppCommitteeSize`) Committee size — The number of members on the voting committee.
1. $\Delta$ Network diffusion time — Upper limit on the time needed to diffuse a message to all nodes.
1. $f$ Active slot coefficient — The probability that a party will be the slot leader for a particular slot.
1. $T_{\text{heal}}$ Healing time
1. $T_{CQ}$ Chain-quality - Ensure the presence of at least one honest block on the chain.
1. $T_{CP}$ Common-prefix — Achieve settlement.
1. $k$ Security parameter — The Ouroboros Praos security parameter.
1. (`ppPerasQuorumWeightThreshold`) Quorum weight threshold
1. Quorum weight threshold margin
1. (`ppPerasMaxCandidateBlockAge`) Genesis safety parameter — size of the window
1. (`ppPerasBootstrapRound`) Peras bootstrap round — Peras round number used to manually bootstrap Peras voting for the first time and to resynchronize voting after unexpected failures.
1. (`ppTruncationRatio`) Committee truncation — a ratio to be used in truncation algorithm to be implemented.
1. (`ppCommitteeRatio`) Committee ratio — alternative variant of the `ppTruncationRatio` and `ppCommiteeSize` that works for both
1. `h` healing factor

There are some facts about those that could detemate the solution:

Some parameters are dependent, we can either make both of them gouvernable and keep relation with guardrails
or we can have at most one.

### Round length $U$

it is a param, but because of time-resolution logistics, it can't be governed during an era
as a result can't be a governable protocol parameter. (TODO: why?)

Epoch lenght must be a multiple of round length $U$, so we should either have guardrail it or epoch length.

### Block selection offset

Parametes is required.

### Certificate expiration

$A$ (`ppPerasCertMaxRounds`) as per CIP is defined by $T_{\text{heal}}$, $T_{CQ}$ and $U$. $T_{CQ}$ is fixed at $k/f$. `T_{heal}` is $k(B/f)$, where $k$ is $1$ or $2$.

### Peras quorum weight threshold

`ppPerasQuorumWeightThreshold` that was proposed could have only one reasonable value of 75%
and should not be governable.

75% is a minimal value that ensures there are no two valid certs in a round with an assumption of 50% adversary,
and higher value just weaken the protocol and does not give extra guarantees.

### Chain ignorance period

TODO: why we do not add it?

### Cool-down period

`K` (Cool-down period) is directly defined in terms of $A$, $T_{CP}$, $U$, thus defined in terms of $T_{\text{heal}}$, $T_{CQ}$, $T_{CP}$, $U$.

### Certification boost

We need this parameter but we need it to be renamed into the more Peras specific name.

### Quorum size

TODO: why we do not need it

### Commitee size

We want to add that value. We need this parameter if we use WFLA.

Commitee size is only useful in case if we use selection, but still may be useful. If not defined, we will have to share the
value with Leios.

Commitee size changes the size of the certificate.

It's still possible to use the value in case of the truncation based committee

The alternatives are: **committee truncation**, **commitee ratio**.

### Network diffusion time

Is not a governable paramter and is a global one

### Active slot coefficient

Is not a governable paramter and is a global one

### Healing time

Can be introduced. But maybe should not be gouvernable

alternative is healing factor `h`, only one should be set.

### Chain-quality time

Chain-quality time $T_{CQ}$ assumed to be $k/f$ in other parts of Cardano, so it doesn't make sense to use a different value

### Common-prefix time

Common-prefix time $T_{CP}$: its value is shared with other parts of existing infra (TODO: some examples?)

### $k$ Security parameter

If already exists, but we need to change the value when peras is enabled (see [CIP-140][cip-140]).

### Quorum weight threshold

TODO: why we should not add it.

### Quorum weight threshold margin

Quorum weight threshold margin is determined by the committee size. (TODO: where/how?)

### Genesis safety parameter

Will require changes in the genesis codebase and have many internal relations, should not be governable.

### Bootstrap round

Peras round number used to manually bootstrap Peras voting for the first time and to resynchronize voting after unexpected failures.

We should have value (no not enable).

### Committee truncation ratio

The alternatives are: **committee size**, **commitee ratio**.

### Committee committee ratio

The alternatives are: **committee truncation**, **commitee size**.

### Healing factor

Can be introduced

Alternative is healing time.

Current default is 2 (TODO: no explanation why)

## Decision

The change that we're proposing or have agreed to implement.

### Number of parameters

We keep at most one parameter so we do not make decision space too complex to follow.

### Agree on the following parameters

Introduce following parameters:

- $L$ (`ppPerasMinCandidateBlockAge`)  Block selection offset: `SlotInterval`, default: 30
- $B$ (`ppPerasCertBoost`) Certification boost: `Word64`, default: 15
- $n$ (`ppCommitteeSize`) CommiteeSize: `Word16`, detault: 900
- $R_{\text{bootstrap}}$ (`ppPerasBootstrapRound`) Peras bootstrap round: (`StrictMaybe Word64`), default: SNothing

## Consequences

1. We will need to update all the related documents. No more parameters can be added neither removed
until the hardfork will happen

2. We should ensure that we have a nice story for $k$ when peras is enable.

3. We should introduce an additional guardrail that epoch lenght must be a round of the length $U=90$.

[ledger-repo]: https://github.com/IntersectMBO/cardano-ledger
[cip-140]: https://cips.cardano.org/cip/CIP-0140
[peras-design]: https://github.com/tweag/cardano-peras/tree/main/design
[cardano-constitution]: https://cardano.org/constitution/
[consensus-repo]: https://github.com/IntersectMBO/ouroboros-consensus
[genesis-paper]: https://dl.acm.org/doi/10.1145/3243734.3243848
