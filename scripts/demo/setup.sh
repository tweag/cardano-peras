#!/usr/bin/env bash

set -e
set -x

mkdir -p bin src

# Clone needed repositories
if [[ ! -d src/cardano-base ]]; then
  git clone https://github.com/IntersectMBO/cardano-base src/cardano-base
fi

if [[ ! -d src/ouroboros-network ]]; then
  git clone https://github.com/IntersectMBO/ouroboros-network src/ouroboros-network
fi

if [[ ! -d src/ouroboros-consensus ]]; then
  git clone https://github.com/IntersectMBO/ouroboros-consensus src/ouroboros-consensus
fi

if [[ ! -d src/cardano-node ]]; then
  git clone https://github.com/IntersectMBO/cardano-node src/cardano-node
fi

# Checkout specific commits/branches
git -C src/cardano-base        checkout 5c18017546dc1032e76a985c45fe7c3df2a76616
git -C src/ouroboros-network   checkout peras/10.5
git -C src/ouroboros-consensus checkout peras/10.5

# Cherry-pick the changes from #1684 into ouroboros-consensus/peras/10.5
pushd src/ouroboros-consensus

PR=1684
BASE_BRANCH=peras-staging
git fetch origin "$BASE_BRANCH" pull/"$PR"/head:pr-"$PR"
mapfile -t PR_COMMITS < <(git log --format="%H" --reverse origin/"$BASE_BRANCH"..pr-"$PR")

git reset --hard origin/peras/10.5 # for idempotency
git -c user.name="none" -c user.email="none" cherry-pick "${PR_COMMITS[@]}"

popd

# Build the needed binaries inside cardano-node
pushd src/cardano-node

# cardano-cli @master
if [[ ! -f ../../bin/cardano-cli ]] || [[ -n "$REBUILD_CARDANO_CLI" ]]; then
  git checkout master
  nix develop -c cabal clean
  nix develop -c cabal build cardano-cli
  cp "$(nix develop -c cabal list-bin cardano-cli)" ../../bin/cardano-cli
fi

# cardano-testnet @master
if [[ ! -f ../../bin/cardano-testnet ]] || [[ -n "$REBUILD_CARDANO_TESTNET" ]]; then
  git checkout master
  nix develop -c cabal clean
  nix develop -c cabal build cardano-testnet
  cp "$(nix develop -c cabal list-bin cardano-testnet)" ../../bin/cardano-testnet
fi

# cardano-node @peras/10.5
if [[ ! -f ../../bin/cardano-node ]] || [[ -n "$REBUILD_CARDANO_NODE" ]]; then
  git checkout peras/10.5
  cat > cabal.project.local <<EOF
----- PERAS DEMO -----
program-options
  ghc-options: -Wwarn

packages:
  ../cardano-base/cardano-base

packages:
  ../ouroboros-network/ouroboros-network
  ../ouroboros-network/ouroboros-network-api
  ../ouroboros-network/ouroboros-network-framework
  ../ouroboros-network/ouroboros-network-mock
  ../ouroboros-network/ouroboros-network-protocols

packages:
  ../ouroboros-consensus/ouroboros-consensus
  ../ouroboros-consensus/ouroboros-consensus-cardano
  ../ouroboros-consensus/ouroboros-consensus-protocol
  ../ouroboros-consensus/ouroboros-consensus-diffusion
----- PERAS DEMO -----
EOF
  nix develop -c cabal build cardano-node
  cp "$(nix develop -c cabal list-bin cardano-node)" ../../bin/cardano-node
  rm cabal.project.local
fi

popd
