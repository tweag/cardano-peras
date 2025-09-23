#!/usr/bin/env bash

set -e

CARDANO_CLI=$(realpath bin/cardano-cli)
CARDANO_NODE=$(realpath bin/cardano-node)
CARDANO_TESTNET=$(realpath bin/cardano-testnet)
STATIC_ENV=$(realpath env)
TESTNET_ENV=$(realpath testnet)
STATIC_FILES=$(realpath src/ouroboros-consensus/static)

# Recreate the testnet environment
rm -rf "$TESTNET_ENV"
cp -r "$STATIC_ENV" "$TESTNET_ENV"

# Update the "startup timestamp" field in a couple of places
ISO_8601_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
jq --arg ts "$ISO_8601_TS" \
  '. + { "systemStart": $ts }' \
  "$STATIC_ENV/shelley-genesis.json" > \
  "$TESTNET_ENV/shelley-genesis.json"

EPOCH_TS=$(date -u +"%s")
jq --argjson ts "$EPOCH_TS" \
  '. + { "startTime": $ts }' \
  "$STATIC_ENV/byron-genesis.json" > \
  "$TESTNET_ENV/byron-genesis.json"

# Setup a watcher for the server to announce itself and open the web UI
wait_for_server() {
  local node_to_watch="$1"
  local logfile="$TESTNET_ENV/logs/$node_to_watch/stdout.log"
  local pattern="Serving files at: (\S+)"
  local match;

  while [ ! -f "$logfile" ]; do
    sleep 1
  done

  # Watch the log file for the server URL and open it in the browser
  while read -r line; do
    if [[ "$line" =~ $pattern ]]; then
      match="${BASH_REMATCH[1]}"
      echo "==============================="
      echo "Detected server URL: $match"
      echo "Opening web UI in the default browser ..."
      echo "==============================="
      sleep 3
      xdg-open "$match"
      break
    fi
  done < <(tail -n +1 -F "$logfile")
}

wait_for_server "node1" &

# Export variables needed by cardano-testnet
export CARDANO_CLI
export CARDANO_NODE

# Export variables needed to enable Peras+CertConjuring in cardano-node
export ENABLE_PERAS=1
export PERAS_CERT_CONJURING=1
export PERAS_CERT_CONJURING_STATIC_FILES="$STATIC_FILES"

# Launch the testnet
$CARDANO_TESTNET cardano --node-env "$TESTNET_ENV"


