# Dev

## Entering the dev shell

```
nix shell .#testnet
cd testnet
```

## Running the testnet setup with a pinned cardano-node

```
./launch.sh vanilla
```

`vanilla` can be omitted since it's a default scenario.
See [`scenarios/`](./scenarios) for the rest. They configure the node topology,
stake distribution, genesis params, and fault injection.
`./launch.sh --help` lists what's available.

## Running the testnet setup with a custom cardano-node

```
export CARDANO_NODE=...
export CARDANO_CLI=...
export CARDANO_TESTNET=...
./launch.sh vanilla
```

You can also specify the executables in the scenario file using
`topology.executables` field.

## Running the UI to watch the state of the testnet

```
./launch.sh ui
```

## Developing with a custom cardano-node

TODO.

## Transitioning to Dijkstra

TODO.
