#!/usr/bin/env bash

set -e

if [ -d "$DEVENV_PATH" ]; then
  echo "Devenv path exists at ./${DEVENV_PATH}, checking repos..." >&2
else
  echo "Setting up Peras devenv at ./${DEVENV_PATH} with
  cardano-node:${CARDANO_NODE_SHA}
  ouroboros-consensus:${OUROBOROS_CONSENSUS_SHA}
"

  mkdir -p ${DEVENV_PATH}
fi

# Checkout cardano-node if we haven't already.
if [ ! -d "${DEVENV_PATH}/cardano-node" ]; then
  git clone git@github.com:tweag/cardano-node.git ${DEVENV_PATH}/cardano-node
fi

# Make sure cardano-node has CARDANO_NODE_SHA as an ancestor. If not, the
# starting the testnet will fail, so we must check out that commit.
pushd ${DEVENV_PATH}/cardano-node > /dev/null
# Only fetch if we don't already have the pinned commit locally.
if ! git cat-file -e "${CARDANO_NODE_SHA}^{commit}" 2> /dev/null; then
  git fetch origin
fi
if ! git merge-base --is-ancestor "${CARDANO_NODE_SHA}" HEAD; then
  git checkout "${CARDANO_NODE_SHA}"
fi
popd > /dev/null

if [ ! -d "$DEVENV_PATH"/ouroboros-consensus ]; then
  git clone git@github.com:tweag/ouroboros-consensus.git ${DEVENV_PATH}/ouroboros-consensus
  pushd ${DEVENV_PATH}/ouroboros-consensus > /dev/null
  git checkout "${OUROBOROS_CONSENSUS_SHA}"
  popd > /dev/null
fi

if [ ! -f "$DEVENV_PATH"/build-node.sh ]; then

cat << 'EOF' >> "$DEVENV_PATH"/build-node.sh
#!/usr/bin/env bash

set -e
pushd cardano-node > /dev/null

nix develop -c bash "$PWD/../../scripts/build-node-with-local-packages.sh"
popd > /dev/null
EOF

chmod +x "$DEVENV_PATH"/build-node.sh
fi

if [ ! -f "$DEVENV_PATH"/run-testnet.sh ]; then
cat << 'EOF' >> "$DEVENV_PATH"/run-testnet.sh
#!/usr/bin/env bash

set -e
export CARDANO_NODE=$(find "$PWD" -type f -executable -name "cardano-node" -print -quit)
nix run ../.#testnet $1
EOF

chmod +x "$DEVENV_PATH"/run-testnet.sh
fi

echo "Ready.

Now you can enter the devenv to build the node and run the testnet:

cd devenv
./build-node.sh
./run-testnet.sh vanilla"
