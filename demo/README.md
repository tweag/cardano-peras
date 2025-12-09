# Peras Demos

## 2025-11-24

  - [Slides](https://docs.google.com/presentation/d/18mBH7hy4qYG9rtxHPHvqo2go7-fPkdRM/edit?usp=drive_link&ouid=107877809765303528718&rtpof=true&sd=true)

## 2025-10-27

 - [Slides](https://docs.google.com/presentation/d/1GKMUFtl9rJZdz1c8t_GI_yktcsdXFCzJUU3XHOVxtcU/edit)
 - [Recording](https://drive.google.com/file/d/1QYO81Y8UOi_xynq9HnbZB4WTDNg5mpdP/view)
 - [Chat](https://drive.google.com/file/d/1fByr44aBJVEMcCG8QB1QUrfoyofbJ57I/view)
 - [Gemini summary](https://docs.google.com/document/d/1d5sWZ54R5POeNz8hZl9zoMIwfP04u4skMiXG0DyMEuk/edit)

## 2025-09-29

### Slides and Recordings

 - [Slides](https://docs.google.com/presentation/d/1jfzJSgQ5LMDR8w6WGSjjPg6vb6kQekWv16fdttjS5Iw/edit)
 - [Recording](https://drive.google.com/file/d/17mW08TV0JirL-LTUXj_7Q06rP_sfody3/view)
 - [Chat](https://drive.google.com/file/d/1_F2dNzicKq476iYmDMP3dKghfltwS0Tu/view)
 - [Gemini summary (no warranty)](https://docs.google.com/document/d/1BfzHcUD6XMUD898ruRnyUas1aSJzd9cMO7EnsY7wKbE/edit)

### Interactive demo

We have prepared a small interactive demo to showcase the first milestone of this project. You can find the meeting slides [here](https://docs.google.com/presentation/d/1jfzJSgQ5LMDR8w6WGSjjPg6vb6kQekWv16fdttjS5Iw/edit) for more information.

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
