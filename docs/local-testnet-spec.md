# Testnet specification

This document collects thoughts/commentaries/vision on how the local testnet should behave.

There are two main areas where it would be helpful:

1. Start a development environment providing multiple configuration options for Peras developers.
2. Run integration tests in such environment & setups.

# Development environment

We want to be able to run one command that would:

1. create a local testnet environment (devnet)
2. start necessary processes (cardano-nodes, monitoring services, population scripts, etc)
3. provide a way to observe the behaviour of the testnet

We already use `cardano-testnet` together with `process-compose` for (1) and (2). We already has our own `testnet` executable written in Haskell to invoke necessary commands, generate configuration, control `toxiproxy` cluster, etc. We also have a separate TUI `ui` written in Haskell to observer the behaviour of the testnet.

As a Peras developer, I want to be able to run something like `nix run .#testnet` command to start the testnet and observer its behaviour. There are should be different setup configurations:

- `nix run .#testnet vanilla`
- `nix run .#testnet isolated-latency`
- `nix run .#testnet stake-60-40`
- something else

and so on. The details and scenarios should be easy to configure and flexible. It's not clear yet what setups are needed.

That means we want to be able to choose:

- how many nodes to run
- which nodes to run (SPOs or relay)
- run nodes in groups, e.g. 3 groups with 3 nodes in each group 
- control the stakes distribution among groups
- something else

The `nix run` command should use the pinned `cardano-node` executables by default but also be able to use executables provided by environment variables usch as `CARDANO_NODE`, `CARDANO_TESTNET` and `CARDANO_CLI`. This is important since Peras developers build their own executables locally and want to run the local testnet against these executables.
