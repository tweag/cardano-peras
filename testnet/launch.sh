#!/usr/bin/env bash

set -e

if [ -z "$TESTNET_BIN" ]; then
    cabal build testnet
    TESTNET_BIN=$(cabal list-bin testnet)
fi
echo "Using TESTNET_BIN=$TESTNET_BIN"

case "${1:-}" in
    testnet)
        process-compose \
            -f <("$TESTNET_BIN" stdout-compose-yaml "$TESTNET_BIN") \
            -p 3030
        ;;
    ui)
        "$TESTNET_BIN" ui
        ;;
    *)
        echo "Usage: $0 {testnet|ui}"
        exit 1
        ;;
esac
