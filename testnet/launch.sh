#!/usr/bin/env bash

set -e

if [ -z "$TESTNET_BIN" ]; then
    cabal build testnet
    TESTNET_BIN=$(cabal list-bin testnet)
fi
echo "Using TESTNET_BIN=$TESTNET_BIN"

process-compose -f <($TESTNET_BIN stdout-compose-yaml "$TESTNET_BIN") -p 3030
