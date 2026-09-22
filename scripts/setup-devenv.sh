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
  git clone git@github.com:tweag/cardano-node.git ${DEVENV_PATH}/cardano-node
  pushd ${DEVENV_PATH}/cardano-node > /dev/null
  git checkout 053ad3e439881a59f108dfa0b780f7f426d18e47 
  popd > /dev/null
fi

if [ ! -d "$DEVENV_PATH"/ouroboros-consensus ]; then
  git clone git@github.com:tweag/ouroboros-consensus.git ${DEVENV_PATH}/ouroboros-consensus
  pushd ${DEVENV_PATH}/ouroboros-consensus > /dev/null
  git checkout 7b8ee9bb54fc4359a1e96d9920eda5b70917ef88 
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
