#!/usr/bin/env bash

set -e

if [ -z "$TESTNET_CMD" ]; then
    export TESTNET_CMD="cabal run testnet --"
fi
echo "Using TESTNET_CMD=$TESTNET_CMD"

if [ -z "$COMPOSE_YAML" ]; then
    export COMPOSE_YAML="./process-compose.yaml"
fi
echo "Using COMPOSE_YAML=$COMPOSE_YAML"

process-compose -f $COMPOSE_YAML -p 3030
