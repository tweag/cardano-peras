# Weekly status updates

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
