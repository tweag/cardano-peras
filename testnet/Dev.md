# Dev

## Entering the dev shell

```
nix shell .#testnet
cd testnet
```

## Running the testnet setup with a pinned cardano-node

```
./launch testnet
```

## Running the testnet setup with a custom cardano-node

```
export CARDANO_NODE=...
export CARDANO_CLI=...
export CARDANO_TESTNET=...
./launch testnet
```

## Running the UI to watch the state of the testnet

```
./launch ui
```
