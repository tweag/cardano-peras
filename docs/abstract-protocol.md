# Ouroboros Peras as an abstract protocol

## Preliminaries

### Adversary

Conservatively, we assume a single coordinated adversary.

### Time

Time is divided into slots, and we assume that all parties have access to a perfectly synchronized clock indicating the current slot.

### Network

We assume that all parties can diffuse arbitrary messages via an abstract network functionality.
The network is $\Delta$-semi-synchronous, which means:

 - If an honest party diffuses a messages in slot $s$, all other honest parties receive that message no later than in slot $s + \Delta$.
 - The adversary gets to decide the delay for each honest party individually, subject to the above constraint.

### Stake

Each party has some amount of stake $\sigma$.
The adversary is assumed to control parties having less than 50% of all stake.

### Leader schedule for blocks

A party with stake $\sigma$ is elected in any given slot with probability $\phi(\sigma) = 1 - {(1-\mathrm{asc})}^\sigma$ (independent events for different slots) where $\mathrm{asc}$ is a protocol parameter.

### Transactions

We assume that all honest parties have access to some source of transactions.

## Praos

### Fundamental properties

#### Common Prefix

Let $C_1,C_2$ be the chains adopted by two parties at slot $s_1 \le s_2$.
Let $C_1'$ be the the chain obtained by removing the last `kcp` blocks from $C_1$.
Then $C_1'$ is a prefix of $C_2$.

#### Chain Growth

Consider a chain $C$ selected by an honest party.
Then any window of slots of size $T_{cp}$ ending before the tip of $C$ contains at least `kcp` blocks.

#### Chain Quality

Consider a chain $C$ selected by an honest party.
Then any window of slots of size $T_{cq}$ ending before the tip of $C$ contains at least one honest block.

### Protocol description

#### State

 - The currently selected (best) chain $C_{\mathrm{pref}}$, initialized at the empty chain rooted at Genesis.
 - The set of chains $\mathcal{C}$ received so far, initialized at the singleton set containing the empty chain rooted at Genesis.

#### Logic

At the beginning of every slot, every honest party does the following:

##### Fetching chains

 1. Add all new valid chains to $\mathcal{C}$.
 2. Remove all chains from $\mathcal{C}$ that intersect with $C_{\mathrm{pref}}$ more than `kcp` blocks in the past.
 3. Set $C_{\mathrm{pref}}$ to the longest chain in $\mathcal{C}$.

##### Forging

 1. Check if the party is elected in the current slot.
 2. If so, extend $C_{\mathrm{pref}}$ with a new block with as many transactions as possible.
 3. Diffuse $C_{\mathrm{pref}}$.

## Peras

### Committees, votes and certificates

Time is divided into consecutive *rounds* for Peras, each of size `perasRoundSlots` in terms of slots.

Every round has a *weighted committee*, ie a set of parties with associated weights (summing to one).
The core requirement is that the adversary always has less than 50% of the weight.

Every party that is part of the committee of a round can cast a vote for a particular block.

By a quorum intersection argument, at most one block can receive votes having at least 75% of the weight.
A certificate for a round is a (representation of a) collection of votes with at least 75% weight, all voting for the same block.
We say that such a block is *boosted*.

Boosted blocks get additional weight in chain comparisons during chain selection.

### Fundamental properties

Like for Praos, but now with weight instead of the number of blocks:

#### Common Prefix

Let $C_1,C_2$ be the chains adopted by two parties at slot $s_1 \le s_2$.
Let $C_1'$ be the the chain obtained by removing blocks from $C_1$ until we reach a block that was buried under weight `kcp`.
Then $C_1'$ is a prefix of $C_2$.

#### Chain Growth

Consider a chain $C$ selected by an honest party.
Then any window of slots of size $T_{cp}$ ending before the tip of $C$ contains blocks having at least weight `kcp`.

#### Chain Quality

Consider a chain $C$ selected by an honest party.
Then any window of slots of size $T_{cq}$ ending before the tip of $C$ contains at least one honest block.

#### State

 - The currently selected (best) chain $C_{\mathrm{pref}}$, initialized at the empty chain rooted at Genesis.
 - The set of chains $\mathcal{C}$ received so far, initialized at the singleton set containing the empty chain rooted at Genesis.
 - The set of votes $\mathcal{V}$ received so far
 - The set of certificates $\mathrm{Certs}$ received so far, as well as the respective arrival/emergence slots.

For convenience:

 - $\mathrm{cert}'$ is the certificate in $\mathrm{Certs}$ with the highest round number.
 - $\mathrm{cert}^*$ is the certificate contained in a block on $C_{\mathrm{pref}}$ with the highest round number.

#### Logic

At the beginning of every slot $s$, every honest party does the following:

##### Fetching

 1. Add all new valid chains to $\mathcal{C}$, and all new valid votes to $\mathcal{V}$.
 2. Add all certificates in $\mathcal{C}$ to $\mathrm{Certs}$.
 3. Turn any quorum in $\mathcal{V}$ into a certificate, and add it to $\mathrm{Certs}$.
 2. Remove all chains from $\mathcal{C}$ that intersect with $C_{\mathrm{pref}}$ more than `kcp` weight in the past.
 3. Set $C_{\mathrm{pref}}$ to the weightiest chain in $\mathcal{C}$.

##### Forging

 1. Check if the party is elected in the current slot, otherwise, abort.
 2. If so, extend $C_{\mathrm{pref}}$ with a new block
     - with as many transactions as possible, and
     - with $\mathrm{cert}'$ if

        1. there is no round-$`(r-2)`$ certificate in $\mathrm{Certs}$, and
        2. $r - \mathrm{round}(\mathrm{cert}') \le \mathrm{perasCertMaxRounds}$, and
        3. $\mathrm{round}(\mathrm{cert}') > \mathrm{round}(\mathrm{cert}^*)$,

       where $r$ is the current round.
 3. Diffuse $C_{\mathrm{pref}}$.

##### Voting

 1. Check if $s$ is the first slot of a round $r$, otherwise, abort.
 2. Check if the party is part of the committee of round $r$, otherwise, abort.
 2. Let $B$ be the block to potentially vote for, given by the most recent block on $C_{\mathrm{pref}}$ that is at least $\mathrm{perasBlockMinSlots}$ older than $s$.
 3. Check if either (VR-1A) and (VR-1B), or (VR-2A) and (VR-2B) are satisfied, otherwise abort.
     - (VR-1A): $\mathrm{round}(\mathrm{cert}') = r - 1$, and $\mathrm{cert}'$ was received within the first $X$ slots of round $r-1$.
     - (VR-1B): $B$ extends the block boosted by $\mathrm{cert}'$.
     - (VR-2A): $r \ge \mathrm{round}(\mathrm{cert}') + \mathrm{perasIgnoranceRounds}$.
     - (VR-2B): $r = \mathrm{round}(\mathrm{cert}^*) + c \cdot \mathrm{perasCooldownRounds}$ for some integer $c>0$.
 3. Diffuse a vote for $B$.
