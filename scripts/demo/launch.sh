#!/usr/bin/env bash

set -e

CARDANO_CLI=$(realpath bin/cardano-cli)
CARDANO_NODE=$(realpath bin/cardano-node)
CARDANO_TESTNET=$(realpath bin/cardano-testnet)

export CARDANO_CLI
export CARDANO_NODE
export ENABLE_PERAS=1
export PERAS_CERT_CONJURING=1

$CARDANO_TESTNET cardano
