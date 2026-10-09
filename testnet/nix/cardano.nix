{
  pkgs,
  system,
}:

let

  # Patched versions of the necessary dependencies
  deps = {
    # Branch: peras-testnet
    cardano-node = {
      owner = "tweag";
      repo = "cardano-node";
      rev = "64a01ff7e3faa2ec120093e917ac3ea0a8887b09";
      sha256 = "sha256-MN/Tp22V8jRXTcSw2wiGtbkmKQTaxFWe6aoG0tAR93Q=";
      fetchSubmodules = true;
    };
  };

  makeSourceRepoPackage = inp: ''
    source-repository-package
      type: git
      location: https://github.com/${inp.owner}/${inp.repo}.git
      tag: ${inp.rev}
      --sha256: ${inp.sha256}
  '';

  # Patch the cardano-node project and extract the cardano-node executable
  cardanoNodeExe =
    exe:
    let
      project = (import (pkgs.fetchFromGitHub deps.cardano-node) { inherit system; }).project.${system};
      patchedProject = project.appendModule {
        # Override default GHC to enable compiling with warnings
        # NOTE: using a module is a workaround for
        # https://github.com/input-output-hk/haskell.nix/issues/1149
        modules = [ { ghcOptions = [ "-Wwarn" ]; } ];
      };
    in
    patchedProject.hsPkgs.${exe}.components.exes.${exe};

in
{
  deps = deps;
  cardano-node = cardanoNodeExe "cardano-node";
  cardano-cli = cardanoNodeExe "cardano-cli";
  cardano-testnet = cardanoNodeExe "cardano-testnet";
  cardano-tracer = cardanoNodeExe "cardano-tracer";
  cardano-node-chairman = cardanoNodeExe "cardano-node-chairman";
}
