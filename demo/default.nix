{
  pkgs,
  system,
}:
let
  # Patched versions of the necessary dependencies
  deps = {
    ouroboros-network = pkgs.fetchFromGitHub {
      owner = "IntersectMBO";
      repo = "ouroboros-network";
      rev = "peras/10.5";
      sha256 = "sha256-SQbnKpvnxpkg3VruB+sivZzizsqNXh50uHD+QA0GSgo=";
    };
    ouroboros-consensus = pkgs.fetchFromGitHub {
      owner = "IntersectMBO";
      repo = "ouroboros-consensus";
      rev = "peras/10.5-with-cert-conjuring";
      sha256 = "sha256-f/hwfPpn6Lcw3FisdQ5RdGf7wSsS7k1vJo8q7lmDUuo=";
    };
    cardano-base = pkgs.fetchFromGitHub {
      owner = "IntersectMBO";
      repo = "cardano-base";
      rev = "5c18017546dc1032e76a985c45fe7c3df2a76616";
      sha256 = "sha256-oWmWez/XRIkncGsShxENvzsCoY58Nb0oKu9RvO0oR7w=";
    };
    cardano-node = pkgs.fetchFromGitHub {
      owner = "IntersectMBO";
      repo = "cardano-node";
      rev = "peras/10.5";
      sha256 = "sha256-mxZ4ZhcZG06LF9AhhjrV8ADgC4gIelq9ThXDHvBOjdg=";
    };
  };

  # Patch the cardano-node project and extract the cardano-node executable
  cardano-node =
    let
      project = (import deps.cardano-node { inherit system; }).project.${system};
      patchedProject = project.appendModule {
        # Override default packages with patched versions
        cabalProjectLocal = ''
          packages:
            ${deps.cardano-base}/cardano-base

          packages:
            ${deps.ouroboros-network}/ouroboros-network
            ${deps.ouroboros-network}/ouroboros-network-api
            ${deps.ouroboros-network}/ouroboros-network-framework
            ${deps.ouroboros-network}/ouroboros-network-mock
            ${deps.ouroboros-network}/ouroboros-network-protocols

          packages:
            ${deps.ouroboros-consensus}/ouroboros-consensus
            ${deps.ouroboros-consensus}/ouroboros-consensus-cardano
            ${deps.ouroboros-consensus}/ouroboros-consensus-protocol
            ${deps.ouroboros-consensus}/ouroboros-consensus-diffusion
        '';
        # Override default GHC to enable compiling with warnings
        # NOTE: using a module is a workaround for
        # https://github.com/input-output-hk/haskell.nix/issues/1149
        modules = [ { ghcOptions = [ "-Wwarn" ]; } ];
      };
    in
    patchedProject.hsPkgs.cardano-node.components.exes.cardano-node;

in
pkgs.writeShellApplication {
  name = "demo";
  runtimeInputs = with pkgs; [
    cardano-node
    toxiproxy
    jq
  ];
  runtimeEnv = {
    CARDANO_NODE = "${cardano-node}/bin/cardano-node";
    STATIC_FILES = "${deps.ouroboros-consensus}/static";
    TESTNET_ENV = ./env;
  };
  text = builtins.readFile ./launch.sh;
}
