# Peras-specific Git process

This is a short description of the Git/GitHub workflow for Peras-related changes, extending the upstream [Consensus Git Processes](https://ouroboros-consensus.cardano.intersectmbo.org/docs/howtos/contributing/consensus_git_process)

## Branches

The development of Peras will largely take place in [`ouroboros-consensus`](github.com/IntersectMBO/ouroboros-consensus), but will also touch other repositories like [`ouroboros-network`](github.com/IntersectMBO/ouroboros-network), [`cardano-ledger`](github.com/IntersectMBO/cardano-ledger) and [`cardano-node`](github.com/IntersectMBO/cardano-node).

The goal is to merge all changes into the respective repositories *before* Peras is complete (potentially gated behind feature flags, cf. [tweag/cardano-peras#96](https://github.com/tweag/cardano-peras/issues/96)). However, in order to decouple the Peras development from the timeliness of reviews by the maintainers of the respective repository, we will first merge our changes into `peras-staging` branches after review by the Peras team. These branches are based on top of a recent commit on the main branch or a release branch, depending on our needs.

From time to time, changes from `peras-staging` are taken, polished and submitted for inclusion into the main branch of the repository. This way, the amount of changes in `peras-staging` branches to be rebased stays relatively small.

Note that `peras-staging` branches might need (at least temporarily) to depend on `peras-staging` branches from other repositories via [`source-repository-package`s](https://cabal.readthedocs.io/en/stable/cabal-project-description-file.html#taking-a-dependency-from-a-source-code-repository). This requires coordination when rebasing `peras-staging` branches.

## Pull Requests targeting `peras-staging`

Pull requests against `peras-staging` branches must

 - be opened as draft, to indicate that they are not meant to be reviewed by the maintainers of the given repo, and
 - labelled to indicate that they are Peras-specific (if such a label exists).

The PR title may additionally include a `[WIP]` to indicate to the Peras team that it is still work-in-progress (as the draft status cannot be used to signal that).
