{
  pkgs,
  system,
}:

let

  # Patched versions of the necessary dependencies
  deps = {
    # Branch: peras-prototype
    cardano-node = {
      owner = "IntersectMBO";
      repo = "cardano-node";
      rev = "a38eac60bceb1a64a4ffa29e2d49d802787ce171";
      sha256 = "sha256-MdKkcrS8a5tfP/Dx9g4gWbdpFbwLAHvtmdtCtOerKBo=";
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
  cardano-node = cardanoNodeExe "cardano-node";
  cardano-cli = cardanoNodeExe "cardano-cli";
  cardano-testnet = cardanoNodeExe "cardano-testnet";
}
