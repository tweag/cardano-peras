#!/usr/bin/env bash

set -e

CARDANO_CLI=$(realpath bin/cardano-cli)
CARDANO_NODE=$(realpath bin/cardano-node)
CARDANO_TESTNET=$(realpath bin/cardano-testnet)
STATIC_ENV=$(realpath env)
NUM_POOL_NODES=3

export CARDANO_CLI
export CARDANO_NODE

rm -rf "$STATIC_ENV"
$CARDANO_TESTNET \
  create-env \
  --output "$STATIC_ENV" \
  --num-pool-nodes="$NUM_POOL_NODES"
