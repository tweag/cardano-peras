# Weekly status updates

## 2025-07-25

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
