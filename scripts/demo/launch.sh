#!/usr/bin/env bash

set -e

CARDANO_NODE=$(realpath bin/cardano-node)
STATIC_ENV=$(realpath env)
TESTNET_ENV=$(realpath testnet)
STATIC_FILES=$(realpath src/ouroboros-consensus/static)

# Setup a watcher for the server to announce itself and open the web UI
wait_for_http_server() {
  local node_to_watch="$1"
  local logfile="$TESTNET_ENV/logs/node${node_to_watch}/out.log"
  local pattern="Serving files at: (\S+)"
  local match;

  while [ ! -f "$logfile" ]; do
    sleep 1
  done

  # Watch the log file for the server URL and open it in the browser
  while read -r line; do
    if [[ "$line" =~ $pattern ]]; then
      match="${BASH_REMATCH[1]}"
      echo "Found server for node${node_to_watch} running at $match, launching web UI ..."
      sleep 1
      xdg-open "$match"
      break
    fi
  done < <(tail -n +1 -F "$logfile")
}

# Start a pool node in a given port
start_pool_node() {
  local node="$1"
  local port="$2"

  mkdir -p "$TESTNET_ENV/logs/node${node}"
  echo "Starting pool node${node} on port ${port} ..."
  $CARDANO_NODE run \
    --config "$TESTNET_ENV/configuration.yaml" \
    --topology "$TESTNET_ENV/node-data/node${node}/topology.json" \
    --database-path "$TESTNET_ENV/node-data/node${node}/db" \
    --shelley-kes-key "$TESTNET_ENV/pools-keys/pool${node}/kes.skey" \
    --shelley-vrf-key "$TESTNET_ENV/pools-keys/pool${node}/vrf.skey" \
    --shelley-operational-certificate "$TESTNET_ENV/pools-keys/pool${node}/opcert.cert" \
    --byron-delegation-certificate "$TESTNET_ENV/pools-keys/pool${node}/byron-delegation.cert" \
    --byron-signing-key "$TESTNET_ENV/pools-keys/pool${node}/byron-delegate.key" \
    --socket-path "$TESTNET_ENV/node-data/node${node}/sock" \
    --host-addr 127.0.0.1 \
    --port "$port" \
    &> "$TESTNET_ENV/logs/node${node}/out.log"
}

# Start the toxiproxy server
start_toxiproxy_server() {
  echo "Starting toxiproxy server ..."
  toxiproxy-server &> "$TESTNET_ENV/logs/toxiproxy.log"
}

# Create a proxy port for a given node with some latency
create_toxiproxy() {
  local node="$1"
  local in_port="$2"
  local out_port="$3"
  local latency="$4"
  echo "Creating toxiproxy ${in_port}->${out_port} ..."
  toxiproxy-cli create \
    --listen "127.0.0.1:${out_port}" \
    --upstream "127.0.0.1:${in_port}" \
    "node${node}_proxy"
  toxiproxy-cli toxic add \
    --type latency \
    --attribute latency="$latency" \
    "node${node}_proxy"

}

# "Gracefully" stop all pool nodes on script termination
cleanup() {
  echo ""
  echo "Stopping pool nodes ..."
  pkill -f "$CARDANO_NODE" || true
  echo "Stopping toxiproxy server ..."
  pkill -f toxiproxy-server || true
}

# ---------------------------------

# Export variables needed to enable Peras+CertConjuring in cardano-node
export ENABLE_PERAS=1
export PERAS_CERT_CONJURING=1
export PERAS_CERT_CONJURING_STATIC_FILES="$STATIC_FILES"

# Recreate the testnet environment
rm -rf "$TESTNET_ENV"
cp -r "$STATIC_ENV" "$TESTNET_ENV"
mkdir -p "$TESTNET_ENV/logs"

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

# Launch some auxiliary processes
wait_for_http_server 1 &
start_toxiproxy_server &

# Launch 3 pool nodes behind toxiproxy instances with some latency to induce
# network partitions to create forks
NODE_LATENCY_MS=250
for i in $(seq 1 3); do
  in_port=$((3000 + i))
  out_port=$((4000 + i))
  create_toxiproxy "$i" "$in_port" "$out_port" "$NODE_LATENCY_MS"
  start_pool_node "$i" "$in_port" &
done

# Setup a trap waiting for Ctrl+C to stop everything
echo "Press Ctrl+C to stop the testnet ..."
trap cleanup SIGINT
while true; do
  sleep 1
done
