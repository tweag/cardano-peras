## Peras design document

The Peras design document is available
[here as a PDF](https://tweag.github.io/cardano-peras/peras-design.pdf).

### Building

You can build via Nix:

```console
nix build .#design
```

Or inside the Nix shell (enter via `nix develop` or
[nix-direnv](https://github.com/nix-community/nix-direnv)) for a more
interactive experience:

```console
latexmk peras-design.tex
```
