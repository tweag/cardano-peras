#!/usr/bin/env bash

set -e

CARDANO_CLI=$(realpath bin/cardano-cli)
CARDANO_NODE=$(realpath bin/cardano-node)
CARDANO_TESTNET=$(realpath bin/cardano-testnet)
STATIC_FILES=$(realpath src/ouroboros-consensus/static)

export CARDANO_CLI
export CARDANO_NODE
export ENABLE_PERAS=1
export PERAS_CERT_CONJURING=1
export PERAS_CERT_CONJURING_STATIC_FILES="$STATIC_FILES"

OUTPUT_DIR=testnet

rm -rf "$OUTPUT_DIR"
$CARDANO_TESTNET create-env --output "$OUTPUT_DIR"

# Modify the configuration files in $OUTPUT_DIR

$CARDANO_TESTNET cardano --node-env "$OUTPUT_DIR"
