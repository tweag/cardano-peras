# testnet

The testnet allows to run the up to date https://github.com/IntersectMBO/ouroboros-consensus/tree/peras/the-big-pr.

It consists of process-compose, that runs the local testnet with nodes, and UI, that provides monitoring of the running nodes' metrics.

## Running

Start the UI in the first terminal session using,

```
nix run github:tweag/cardano-peras#testnet ui
```

Start the testnet in the second terminal session using,

```
nix run github:tweag/cardano-peras#testnet vanilla
```

(`vanilla` is the default scenario, can be omitted). See
[`scenarios/`](./scenarios) for the rest.

## Development

```
nix run github:tweag/cardano-peras#setup-devenv
```

That should create `devenv` directory, clone recent `cardano-node` and `ouroboros-consensus` repos.

```
cd devenv
./build-node.sh
./run-testnet.sh
```

Will build and run the testnet, allowing to work on peras in the `ouroboros-consensus` directory.
