#!/usr/bin/env bash

set -e

cleanup() {
    trap - EXIT INT TERM
    kill -- -$$ 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if [ -z "$TESTNET_BIN" ]; then
    cabal build testnet
    TESTNET_BIN=$(cabal list-bin testnet)
fi
echo "Using TESTNET_BIN=$TESTNET_BIN"

TESTNET_SCENARIOS_DIR="${TESTNET_SCENARIOS_DIR:-scenarios}"

usage() {
    echo "Usage: $0 [SCENARIO|ui]" >&2
    echo "  SCENARIO defaults to 'vanilla' if omitted." >&2
    echo "Available scenarios:" >&2
    for f in "$TESTNET_SCENARIOS_DIR"/*.yaml; do
        [ -e "$f" ] && echo "  $(basename "$f" .yaml)" >&2
    done
}

runTestnet() {
    scenarioName="${1:-vanilla}"
    scenarioFile="$TESTNET_SCENARIOS_DIR/$scenarioName.yaml"
    if [ ! -f "$scenarioFile" ]; then
        echo "Unknown scenario '$scenarioName': $scenarioFile does not exist." >&2
        usage
        exit 1
    fi
    echo "Using scenario: $scenarioFile"
    export TESTNET_SCENARIO="$scenarioFile"
    process-compose \
        -f <("$TESTNET_BIN" stdout-compose-yaml "$TESTNET_BIN") \
        -p 3030 \
        -L process-compose.log
}

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    ui)
        "$TESTNET_BIN" ui
        ;;
    *)
        runTestnet "${1:-}"
        ;;
esac
