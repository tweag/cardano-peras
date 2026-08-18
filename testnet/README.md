# testnet

You need two terminal sessions to run the complete workflow.

## Executable

Since we need to call the executable twice, it's recommended to build the
executable first.

You can build the executable using,
```
nix build github:tweag/cardano-peras#testnet
```

## Running

Start the UI in the first terminal session using,
```
./result/bin/testnet ui
```

Start the testnet in the second terminal session using,
```
./result/bin/testnet testnet
```

## Development

Refer to the [Dev document](./Dev.md).
