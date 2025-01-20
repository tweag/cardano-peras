## Peras design document

The WIP Peras design document is available [here as a PDF](https://tweag.github.io/cardano-peras/peras-design.pdf).

### Building

You can build via Nix:

```console
nix build
```

Or in the Nix shell (enter via `nix develop` or [nix-direnv](https://github.com/nix-community/nix-direnv)) for a more interactive experience:

```console
cd ./design
latexmk peras-design.tex
```

## Resources

Resources on Peras, recommended to look at in roughly this order:
* Cardano Problem Statement (CPS) on "Settlement Speed", the objective of Peras: https://github.com/cardano-foundation/CIPs/blob/master/CPS-0017/README.md
* Cardano Improvement Proposal (CIP) on Peras directly: https://github.com/cardano-foundation/CIPs/pull/872
  * [Rendered version](https://github.com/cardano-scaling/CIPs/blob/peras/CIP-0140/README.lagda.md) of the proposal
* The [SoW](https://docs.google.com/document/d/1D0E2xYaVF72oUKu9HbLg7F7qsyYLnZbdpw54CVyUmYk/edit?tab=t.0#heading=h.jfb7zrfex5jj)
* Video on Peras by an IOG researcher: https://www.youtube.com/watch?v=HRJzwoArqg4 (ignore the "Avoiding the cooldown phase" part at the end, this is not part of the "pre-alpha" version of Peras that we are focusing on)
* From the [Peras web site](https://peras.cardano-scaling.org/):
  * The [FAQ](https://peras.cardano-scaling.org/docs/faq)
  * The [simulator](https://peras-simulation.cardano-scaling.org)
  * The [dashboard](https://peras.cardano-scaling.org/dashboard/index.html) (just briefly at first)
  * The [technical reports (1&2)](https://peras.cardano-scaling.org/docs/reports/), lots of overlap with the CIP, but sometimes more details, so makes sense to just skim them first
