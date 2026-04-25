{
  pkgs,
  system,
}:

let

  # Patched versions of the necessary dependencies
  deps = {
    # Branch: master
    ouroboros-consensus = {
      owner = "IntersectMBO";
      repo = "ouroboros-consensus";
      rev = "c87aa760001e60f0f0d3353f793eb089adb917e7";
      sha256 = "sha256-p52sFxbcmciyM9piV7fnkrfClyy+kW7pzBOIEBmstcM=";
    };
    # Branch: master
    cardano-node = {
      owner = "IntersectMBO";
      repo = "cardano-node";
      rev = "045bc187a36ef0cbd236db902b85dd8f202fb059";
      sha256 = "sha256-D2HMIr65q0RM9+ZAjbtA9xNKyoKYfr3Kc4Vv4+s64uY=";
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
        # Override default packages with patched versions
        cabalProjectLocal = ''
          ${makeSourceRepoPackage deps.ouroboros-consensus}
        '';
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
