# Peras-specific Git process

This is a short description of the Git/GitHub workflow for Peras-related changes, extending the upstream [Consensus Git Processes](https://ouroboros-consensus.cardano.intersectmbo.org/docs/howtos/contributing/consensus_git_process)

## Branches

The development of Peras will largely take place in [`ouroboros-consensus`](github.com/IntersectMBO/ouroboros-consensus), but will also touch other repositories like [`ouroboros-network`](github.com/IntersectMBO/ouroboros-network), [`cardano-ledger`](github.com/IntersectMBO/cardano-ledger) and [`cardano-node`](github.com/IntersectMBO/cardano-node).

The goal is to merge all changes into the respective repositories _before_ Peras is complete (potentially gated behind feature flags, cf. [tweag/cardano-peras#96](https://github.com/tweag/cardano-peras/issues/96)). However, in order to decouple the Peras development from the timeliness of reviews by the maintainers of the respective repository, we will first merge our changes into `peras-staging` branches after review by the Peras team. These branches are based on top of a recent commit on the main branch or a release branch, depending on our needs.

From time to time, changes from `peras-staging` are taken, polished and submitted for inclusion into the main branch of the repository. This way, the amount of changes in `peras-staging` branches to be rebased stays relatively small.

Note that `peras-staging` branches might need (at least temporarily) to depend on `peras-staging` branches from other repositories via [`source-repository-package`s](https://cabal.readthedocs.io/en/stable/cabal-project-description-file.html#taking-a-dependency-from-a-source-code-repository). This requires coordination when rebasing `peras-staging` branches.

## Pull Requests targeting `peras-staging`

Pull requests against `peras-staging` branches must

- be opened as draft, to indicate that they are not meant to be reviewed by the maintainers of the given repo, and
- labelled to indicate that they are Peras-specific (if such a label exists).

The PR title may additionally include a `[WIP]` to indicate to the Peras team that it is still work-in-progress (as the draft status cannot be used to signal that).

### Merging

Once a PR has been reviewed and is ready, it can be merged through the GitHub UI after marking it as `Ready to review`. However, this may notify repository maintainers about changes that i) were not meant for them to review, and ii) are already merged by the time they check.

To avoid this, we usually merge PRs by pushing directly into `peras-staging`:

```bash
git checkout peras-staging
git merge --ff-only peras/your-fancy-new-feature
git push origin peras-staging
```

GitHub will recognize that the PR’s commits are included in the target branch and automatically close it. Note, however, that this bypasses the configured [merge queue](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue). Using `--ff-only` ensures the merge does not introduce conflicts and helps prevent `peras-staging` from ending up in a broken state.

If `git merge --ff-only` fails, it means your branch cannot be fast-forwarded onto the tip of `peras-staging` as there is at least one divergent commit. To fix this, rebase your feature branch on top of `peras-staging` and then force-push the updated history. This will trigger a new round of CI checks. Once those pass, you should be able to merge with `--ff-only` cleanly.

```bash
git checkout peras/your-fancy-new-feature
git fetch origin
git rebase origin/peras-staging
git push --force-with-lease origin peras/your-fancy-new-feature
```

#### Automated script

We have prepared a small script that runs these manual steps, while also checking that _some_ of the merging criteria are fulfilled (e.g., checks have passed, PR is approved by at least one reviewer, and so on). You can run it directly via:

```console
nix run github:agustinmista/github-draft-merge
```

HINT: if some have not passed, but you're convinced that your PR is good to go, you can pass the `-i/--ignore-checks` flag to the script above. Use this power with caution.

## Multiple repositories and how to synchronize them

As part of this project, we also need to integrate changes into other repositories under the `IntersectMBO` organization, notably `ouroboros-network`. Since `ouroboros-consensus` depends on `ouroboros-network`, the `peras-staging` branch of `ouroboros-consensus` pins down a version of `ouroboros-network` that contains the changes we need downstream. This version also runs along the `peras-staging` branch of `ouroboros-network`, but it doesn't necessarily point to its tip (until we integrate changes downstream).

### Backporting changes

Our development efforts in `ouroboros-network` target its `main` branch. This means that, from time to time, we might need to backport some of the changes introduced in some PRs into the `peras-staging` branch referenced by `ouroboros-consensus`.

Doing this is a bit of an art when it comes to deciding what to include and what to remove, but as a general rule of thumb:

- we want to avoid updating dependencies upstream, and
- it's OK to remove entire test suites if these are not needed downstream.

In addition, when you backport a bunch of commits from one or more PRs into `peras-staging`, it's a good idea to push a `peras-staging/pr-XXX` tag to delimit them:

```
    branch        commits            tags

peras-staging --> a9d91f1 <-- peras-staging/pr-456
                  b82a8d1
                  c891abf <-- peras-staging/pr-123
                  a9b3d91
                  .......
```

### Integrating changes downstream

After you backported the necessary changes in an upstream repository, let's say into `ouroboros-network` at `peras-staging/pr-123`, you can start integrating those changing downstream in repositories depending on it by tweaking the `source-repository-package` stanza in their `cabal.project` file:

```
source-repository-package
   type: git
   location: https://github.com/IntersectMBO/ouroboros-network
   tag: peras-staging/pr-123
   --sha256: sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
   subdir:
     ouroboros-network
     ouroboros-network-protocols
     ouroboros-network-api
```

Worth noting, the `--sha256` comment is not _just_ a comment. It's used by [Haskell.nix](https://input-output-hk.github.io/haskell.nix/tutorials/source-repository-hashes.html) to download this version of the external `ouroboros-network` dependency in a reproducible way. You will need to update this as well to pass CI. The easiest way to get a hold of the updated hash is probably to run:

```console
nix-shell -p nix-prefetch-git --run 'nix-prefetch-git https://github.com/IntersectMBO/ouroboros-network peras-staging/pr-123'
```

And copy the `hash` or the `sha256` field from the output. From there, you should be able to continue developing downstream with the updated version of the external dependency in place.
