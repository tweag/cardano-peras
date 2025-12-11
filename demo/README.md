# Peras Demos

### Interactive Weighted Chain Selection demo

You can try it with Nix:

```console
nix run github:tweag/cardano-peras#demo
```

Or with Docker:

```console
docker run -it --rm --network=host -v ./tmp:/tmp ghcr.io/tweag/cardano-peras/cardano-peras-demo
```

NOTE: with Nix, the demo's web UI will be launched automatically (assuming `xdg-open` is available in your system). With Docker, please follow the link printed at startup:

```
Found server for node1 running at http://localhost:XXXX
```

It's possible to look at the logs for the three different nodes by navigating to the ephemeral testnet directory printed during startup (mounted at `./tmp` when using Docker):

```
Setting up testnet environment in /tmp/demo-testnet-XXXX
```

From there, logs are located under `logs/node(1|2|3)/out.log`. For reference, all certificates are produced by `node1`, and you should be able to see events like `ChainDB.PerasCertDbEvent.AddedPerasCert` in both `node2` and `node3` when those get diffused across the network.
