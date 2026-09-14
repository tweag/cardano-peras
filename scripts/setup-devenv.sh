#!/usr/bin/env bash

set -e

DEVENV_PATH="devenv"

if [ -d "$DEVENV_PATH" ]; then
  echo "Devenv path exists at ./${DEVENV_PATH}, checking repos..." >&2
else
  echo "Setting up Peras devenv at ./${DEVENV_PATH}"
  mkdir -p ${DEVENV_PATH}
fi

if [ ! -d "$DEVENV_PATH"/cardano-node ]; then
  git clone -b peras-testnet-devenv git@github.com:tweag/cardano-node.git ${DEVENV_PATH}/cardano-node
fi

if [ ! -d "$DEVENV_PATH"/ouroboros-consensus ]; then
  git clone -b peras-testnet-devenv git@github.com:tweag/ouroboros-consensus.git ${DEVENV_PATH}/ouroboros-consensus
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
