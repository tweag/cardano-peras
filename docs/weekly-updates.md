# Weekly status updates

## 2025-11-21

 - Refined the [scope](https://github.com/tweag/cardano-peras/issues/170) and started the development of the [Peras Dashboard](https://github.com/tweag/cardano-peras/compare/main...dashboard), to be preliminary hosted [here](https://tweag.github.io/cardano-peras/dashboard/).

 - Coordinated with Alexey Kuleshevich (IOG Ledger team lead) how to integrate the changes needed to store certificates in blocks into Ledger, and started working on the concrete [issues](https://github.com/IntersectMBO/cardano-ledger/issues?q=state%3Aopen%20label%3A%22peras%22%20is%3Aissue) he prepared for us.

 - Started working on the implementation of the [PerasVoteDB](https://github.com/IntersectMBO/ouroboros-consensus/pull/1768) and its associated voting thread.

 - Went through another round of reviews and fixes on [Peras #4](https://github.com/IntersectMBO/ouroboros-consensus/pull/1679) after presenting ObjectDiffusion V1 to the IOG Consensus team.

 - Went through a final round of reviews and fixes for the experimental [ObjectDiffusion V2](https://github.com/IntersectMBO/ouroboros-consensus/pull/1698) mini protocol.

 - Prepared for the public demo on 2025-11-24, see the "Peras" channel on the IOG Discord for how to join.

## 2025-11-14

 - Thomas Bagrel ([@tbagrel1](https://github.com/tbagrel1)) successfully defended his [Ph.D. thesis](https://www.doctorat.univ-lorraine.fr/fr/soutenances/bagrel-thomas)! 🙌🙌🙌

 - Prepared and released the [Peras #4](https://github.com/IntersectMBO/ouroboros-consensus/pull/1679) PR for review of the ouroboros-consensus team, including the initial implementation of the ObjectDiffusion mini protocol.

 - Continued working on the [version 2](https://github.com/IntersectMBO/ouroboros-consensus/pull/1698) of the ObjectDiffusion mini protocol (inbound side only).

 - Started working on the machinery needed to [store certificate in blocks](https://github.com/tweag/cardano-peras/issues/141), needed to coordinate the end of a cooldown period.

## 2025-11-7

 - Started realigning team efforts to tackle the most urgent tasks after unexpected circumstances.

 - Started working on a [small change](https://github.com/IntersectMBO/ouroboros-consensus/pull/1750) to store the most recent certificate seen in the PerasCertDB such that it's not affected by garbage collection.

 - Started working on a [state machine test suite](https://github.com/IntersectMBO/ouroboros-consensus/pull/1751) for the Peras voting rules. The idea is to evaluate if we can effectively test some local properties that should hold regardless of the global state of the blockchain, e.g., "if a node doesn't vote for two consecutive rounds, then it _must_ not vote for at least _R_ rounds (cooldown)."

## 2027-10-31

 - Merged the initial (pure) implementation of the Peras [voting rules](github.com/IntersectMBO/ouroboros-consensus/pull/1723)

 - Made a [small change](https://github.com/IntersectMBO/ouroboros-consensus/pull/1742) to allow for ChainDB state machine tests to use a security parameter larger than 2. This parameter will later be [generated on the fly](https://github.com/IntersectMBO/ouroboros-consensus/issues/1682).

 - [Enhanced header state](https://github.com/IntersectMBO/ouroboros-consensus/pull/1739) to keep track of the previous epoch nonce, which will be necessary later on to validate slightly old certificates.

 - Started working on a [rebase](https://github.com/IntersectMBO/ouroboros-consensus/pull/1748) of our `peras-staging` branch to include the latest changes from `main`, including the already-merged Peras #1, #2, and #3 PRs.

 - Continued working on a benchmarking suite for the version 2 of the ObjectDiffusion mini protocol (inbound side only).

## 2025-10-24

 - Started implementing the Peras voting rules https://github.com/tweag/cardano-peras/issues/116 https://github.com/IntersectMBO/ouroboros-consensus/pull/1723

 - Continued working on adding Peras certificates to block bodies https://github.com/tweag/cardano-peras/issues/141

   Met with Alexey Kuleshevich (IOG Ledger team lead) to discuss possible Ledger↔Consensus interfaces. In particular, there is a new flow of data due to block validation now requiring the epoch nonce from the header state. See https://github.com/tweag/cardano-peras/issues/152.

 - Finished an [implementation design document](https://github.com/IntersectMBO/ouroboros-consensus/blob/peras/experimental-object-diffusion-inbound-v2/ouroboros-consensus/src/ouroboros-consensus/Ouroboros/Consensus/MiniProtocol/ObjectDiffusion/Inbound/V2.md) for efficient Peras Vote Diffusion.

 - Prepared for the public demo on 2025-10-27, see the "Peras" channel on the IOG Discord for how to join.

## 2025-10-17

 - Finished an initial draft of the inbound vote decision logic https://github.com/IntersectMBO/ouroboros-consensus/pull/1698, which now needs to be tested and benchmarked.

 - Started to work on adding Peras certificates to block bodies https://github.com/tweag/cardano-peras/issues/141

   We will synchronize with the Ledger team on this, and also keep the Leios team in the loop as they also need to include certificates in block bodies.

 - Mob review of https://github.com/IntersectMBO/ouroboros-consensus/pull/1678 with the IOG Consensus team, to be continued next week

 - Implemented recording of certificate arrival times, which is necessary for the refined voting rule https://github.com/IntersectMBO/ouroboros-consensus/pull/1703

 - Held an internal session discussing the details of cooldown periods, and how the voting/forging rules are designed to guarantee them.

## 2025-10-10

 - Continued investigation a strategy for efficient vote diffusion, examining the related recently developed logic for transaction diffusion by the IOG Network team and adapting it for our purposes. https://github.com/tweag/cardano-peras/issues/140

 - Implemented a new Peras-related criterion for the Genesis State Machine. https://github.com/IntersectMBO/ouroboros-consensus/pull/1669

 - Merged https://github.com/IntersectMBO/ouroboros-consensus/pull/1674 after addressing the review comments by the IOG Consensus team.

 - Submitted https://github.com/IntersectMBO/ouroboros-consensus/pull/1678 for weighted chain selection for review by the IOG Consensus team.

## 2025-10-02

 - Delivered the first public demo. See [here](../demo/README.md#2025-09-29) for recordings and more.

   In particular, we discussed details of the Peras cryptography and committee selection, in particular w.r.t. alignment with Leios and Mithril, with several action items.

 - Internal meetings on the intrinsics of the Peras voting rules.

   We prepared some [new documentation material](https://github.com/tweag/cardano-peras/pull/138) for that purpose.

 - Submitted the object diffusion mini-protocol and the registration of certificate and vote diffusion for upstream review https://github.com/IntersectMBO/ouroboros-network/pull/5202

   We also discussed this briefly in the IOG Network meeting.

## 2025-09-26

 - Prepared for the demo on 2025-09-29, see the "Peras" channel on the IOG Discord for how to join.

   In particular, we packaged a self-contained testnet for showcasing weighted chain selection and related features https://github.com/tweag/cardano-peras/pull/132

 - Merged the first purely Peras-related PR after addressing review comments by the IOG Consensus team. https://github.com/IntersectMBO/ouroboros-consensus/pull/1673

 - Submitted the PerasCertDB for review by the IOG Consensus team. https://github.com/IntersectMBO/ouroboros-consensus/pull/1674

 - Registered PerasVoteDiffusion as a mini-protocol. https://github.com/IntersectMBO/ouroboros-network/pull/5201

## 2025-09-19

 - Started to develop tooling to graphically showcase certificate diffusion and weighted chain selection in a custom testnet. https://github.com/tweag/cardano-peras/issues/115

   This required backporting our changes to the most recent `ouroboros-consensus` release that was integrated into `cardano-node`, which was non-trivial as this last happened in May. https://github.com/tweag/cardano-peras/issues/125

   We also worked on improvements to `cardano-testnet` to accomodate this use case.

 - Merged PR improving the QuickCheck generators for the ChainDB `quickcheck-state-machine` test. https://github.com/IntersectMBO/ouroboros-consensus/pull/1670

 - Polished and submitted our Peras changes so far for upstream review to the IOG Consensus team:

    - https://github.com/IntersectMBO/ouroboros-consensus/pull/1673
    - https://github.com/IntersectMBO/ouroboros-consensus/pull/1674
    - https://github.com/IntersectMBO/ouroboros-consensus/pull/1678
    - https://github.com/IntersectMBO/ouroboros-consensus/pull/1679
    - https://github.com/IntersectMBO/ouroboros-consensus/pull/1681

 - We finalized our PR adding the ObjectDiffusion mini-protocol, adding codec tests and fixing serialization bugs. https://github.com/IntersectMBO/ouroboros-network/pull/5181

 - The IOG Cryptography reached out, and we aligned on the cryptography required by Peras as well as the intersection with other workstreams like Leios and Mithril. https://github.com/tweag/cardano-peras/issues/128

## 2025-09-12

 - We scheduled our first public demo, see the "Peras" channel on the IOG Discord for how to join.

 - Initialized a minimal library with the notion of experimental feature flags, allowing parallel development of Peras and other upcoming features like Leios/Phalanx/... (https://github.com/IntersectMBO/cardano-base/pull/547)

 - Enriched the Hard Fork Combinator with the concept of Peras rounds https://github.com/IntersectMBO/ouroboros-consensus/pull/1606

 - Improved the randomized testing of weighted chain selection via `quickcheck-state-machine` https://github.com/IntersectMBO/ouroboros-consensus/pull/1670

 - Separated and polished the existing work into easily reviewable chunks for upstream consideration

## 2025-09-05

 - Implemented serialization of Peras certificates https://github.com/IntersectMBO/ouroboros-consensus/pull/1658

 - Wired up Peras certificate diffusion https://github.com/IntersectMBO/ouroboros-consensus/pull/1663

 - Started designing an API for certificate validation https://github.com/IntersectMBO/ouroboros-consensus/pull/1655

 - Improved CI invariant checking https://github.com/IntersectMBO/ouroboros-consensus/pull/1651

 - Merged a PR simplifying the integration of weighted chain selection https://github.com/IntersectMBO/ouroboros-consensus/pull/1619

## 2025-08-29

Most of the team is/was on vacation this week.

 - Finalized initial implementation of certificate diffusion https://github.com/IntersectMBO/ouroboros-consensus/pull/1615

 - Wrote up interactions between the HFC and Peras at era boundaries https://github.com/tweag/cardano-peras/issues/92

   These will need to be addressed eventually, but they are not blocking the near-term implementation.

 - Discussed development approach in the presence of other experimental feature (Nested Transactions/Leios/Phalanx).

   Agreement was reached to merge the features continually as they are developed, while gating them behind feature flags while they are still experimental. This avoids the need for long-running branches.

   The Peras team will work on propagating a set of feature flags to the ecosystem. https://github.com/tweag/cardano-peras/issues/96

## 2025-08-22

Most of the team is/was on vacation this week.

 - Continued work on certificate diffusion https://github.com/IntersectMBO/ouroboros-consensus/pull/1615

 - Started to integrate the certificate diffusion mini-protocol into the Network layer https://github.com/tweag/cardano-peras/issues/78, paving the way to preliminary Peras cluster runs.

## 2025-08-15

Most of the team is/was on vacation this week.

 - Opened https://github.com/tweag/cardano-peras/issues/88 after further discussions with the IOR researchers regarding the possibility to avoid having to store historical certificates. However, to assess the feasibility of this idea, further work is necessary.

 - Walkthrough of https://github.com/IntersectMBO/ouroboros-consensus/pull/1619 with the IOG Consensus team.

 - Reviewed and merged PRs implementing weighted chain selection and weighted immutability (https://github.com/IntersectMBO/ouroboros-consensus/pull/1621 and https://github.com/IntersectMBO/ouroboros-consensus/pull/1594).

 - Discussions and API changes for certificate diffusion https://github.com/IntersectMBO/ouroboros-consensus/pull/1615

 - Briefly discussed potential usage of Peras certificates in light clients and ZK proofs.

## 2025-08-08

 - Met with the IOR researchers regarding Peras.

    - Discussed avenues for improved settlement calculations for the parameterization dashboard https://github.com/tweag/cardano-peras/issues/54

    - Communicated a minor protocol change in the voting rule, potentially enabling further simplifications.

 - Continued work on minimizing exposure of the immutability criterion, in particular targeting the LedgerDB https://github.com/tweag/cardano-peras/issues/71 https://github.com/IntersectMBO/ouroboros-consensus/pull/1619

 - A lot of code review, preparing submission of pull requests for review by the IOG Consensus team.

## 2025-08-01

The components necessary for the Minimal Testnet without Voting (see the [roadmap](./roadmap-draft.md)) are taking shape:

 - Regarding weighted chain comparisons and weighted chain selection:

    - Engaged with the Networking team in reviewing https://github.com/IntersectMBO/ouroboros-network/pull/5161 which enables weighted chain comparisons in the BlockFetch decision logic.

      Also merged https://github.com/IntersectMBO/ouroboros-network/pull/5157.

    - Implemented weight-based immutability criterion https://github.com/tweag/cardano-peras/issues/71.

      This allows our volatile chain fragment to be shorter than `k` blocks when Peras is not in a cooldown period, and improves resource bounding arguments of the node which rely on the age of the immutable tip (which for example is relevant for bounding the size of the VolatileDB).

    - Improved documentation and general polishing of weights and weight calculations https://github.com/IntersectMBO/ouroboros-consensus/pull/1609

 - Regarding certificate diffusion:

    - Wiring between the generic object diffusion mini-protocol implementation and the PerasCertDB https://github.com/IntersectMBO/ouroboros-consensus/pull/1615

    - Started extending the basic smoke tests to sync two PerasCertDBs.

## 2025-07-25

 - Finalized PR optimizing fragment intersections https://github.com/IntersectMBO/ouroboros-network/pull/5157

   This is an operation that will happen on every chain comparison, so it needs to be fast.

 - Implemented chain selection for certificates https://github.com/tweag/cardano-peras/issues/68

 - Added basic tests for weighted chain selection https://github.com/tweag/cardano-peras/issues/69

 - Smoke test for a very simple version of object diffusion https://github.com/IntersectMBO/ouroboros-consensus/tree/peras/object-diffusion

## 2025-07-18

Half of the team was on vacation this week, so only a short update.

 - Progress on weighted chain comparisons and weighted chain selection https://github.com/tweag/cardano-peras/issues/62

    - Merged supporting refactoring in the Consensus layer https://github.com/IntersectMBO/ouroboros-consensus/pull/1591

    - Enriched BlockFetch decision logic to allow weighted chain comparisons https://github.com/tweag/cardano-peras/issues/62

    - Draft PR for weighted chain comparisons (including weighted chain selection) in the Consensus layer https://github.com/IntersectMBO/ouroboros-consensus/pull/1594

## 2025-07-11

 - Finished initial scaffolding of Peras certs and PerasCertDB https://github.com/tweag/cardano-peras/issues/59

   Implemented a basic state machine test for the PerasCertDB https://github.com/IntersectMBO/ouroboros-consensus/pull/1582

 - Implemented baseline microbenchmark for calculating weight of chains https://github.com/IntersectMBO/ouroboros-consensus/pull/1583

 - Started designing weighted chain comparisons and weighted chain selection https://github.com/tweag/cardano-peras/issues/62

 - More work basic object diffusion https://github.com/tweag/cardano-peras/issues/57, in particular regarding protocol polymorphism

 - Update to Peras CIP got merged https://github.com/cardano-foundation/CIPs/pull/1048

## 2025-07-04

 - Wrote a [document](./pre-alpha.md) explaining pre-alpha Peras

 - Submitted an update to the Peras CIP: https://github.com/cardano-foundation/CIPs/pull/1048

 - Started scaffolding for Peras certs and PerasCertDB: https://github.com/tweag/cardano-peras/issues/59 https://github.com/IntersectMBO/ouroboros-consensus/pull/1581

 - Started implementing basic object diffusion https://github.com/tweag/cardano-peras/issues/57

 - [@tbagrel1](https://github.com/tbagrel1) started onboarding as a new team member 🙌

## 2025-06-27

 - Merged [various updates](https://github.com/tweag/cardano-peras/pull/52) to the Peras report, including:
    - New appendices with more details on the vote and certificate cryptography, and some preliminary considerations for a reward scheme.
    - Potential improvements on optimizing vote diffusion.
    - Rollout considerations, such as KES agent integration and a key registration period.

 - Drafted a concrete [implementation roadmap](https://github.com/tweag/cardano-peras/blob/main/docs/roadmap-draft.md).

 - Collected [feature wishlist](https://github.com/tweag/cardano-peras/issues/54) for parameterization dashboard.
