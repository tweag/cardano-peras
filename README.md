# Assorted Material for the Design and Implementation of Ouroboros Peras on Cardano

> [!WARNING]
> In this repository, "Peras" is referring to [**pre-alpha**](./docs/pre-alpha.md) Peras unless stated otherwise.

This repository currently contains:

 - [Design document](https://tweag.github.io/cardano-peras/peras-design.pdf)
 - [Draft implementation roadmap](./docs/roadmap-draft.md)
 - [Weekly updates](./docs/weekly-updates.md)
 - [Past demos](./demo/README.md)

## Resources on Peras

Most of the following resources were created by the IOR Peras research team and the IOG Peras Innovation team.

* Video on Peras by Sandro Coretti-Drayton (IOG researcher on Peras): https://www.youtube.com/watch?v=HRJzwoArqg4

  Great overview of the abstract protocol. Also talks about pre-agreement in the "Avoiding the cooldown phase" part at the end, which is not part of [pre-alpha](./docs/pre-alpha.md) Peras.

* Slides from the Peras workshop: https://docs.google.com/presentation/d/1ZNHq6xZCR1Tz1wt0n8VyqZkrsCC65O79tlAN67JJKA0/edit

* Cardano Problem Statement (CPS) on "Settlement Speed", the objective of Peras: https://github.com/cardano-foundation/CIPs/blob/master/CPS-0017/README.md

* Cardano Improvement Proposal (CIP) for Peras: https://github.com/cardano-foundation/CIPs/blob/master/CIP-0140/README.md

  Includes a formal Agda specification of the abstract protocol, as well as analyses of resource impact and certain adversarial scenarios.

* From the [Peras web site](https://peras.cardano-scaling.org/)
  * The [FAQ](https://peras.cardano-scaling.org/docs/faq)
  * The [simulator](https://peras-simulation.cardano-scaling.org)
  * The [dashboard](https://peras.cardano-scaling.org/dashboard/index.html) (preliminary settlement probabilities)
  * The [technical reports (1&2)](https://peras.cardano-scaling.org/docs/reports/)

    Lots of overlap with the CIP, sometimes outdated, but sometimes more detailed.

## Peras design document

The Peras design document is available [here as a PDF](https://tweag.github.io/cardano-peras/peras-design.pdf).

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
