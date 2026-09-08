{
  pkgs,
  system,
  CHaP,
  iohkNix,
}:

let

  cardano = import ./nix/cardano.nix {
    inherit pkgs;
    inherit system;
  };

  # `cooked-validators` and its cardano dependencies (via CHaP) need the
  # custom crypto libraries (libsodium-vrf, libblst) and the corresponding
  # haskell.nix pkg-config mappings from iohk-nix. This overlay is only
  # applied to `pkgs` locally, to avoid affecting other sub-projects.
  pkgsWithCrypto = pkgs.appendOverlays [
    iohkNix.overlays.crypto
    iohkNix.overlays.haskell-nix-crypto
  ];

  extraInputs = [
    cardano.cardano-node
    cardano.cardano-cli
    cardano.cardano-testnet
    pkgs.process-compose
    pkgs.curl
    pkgs.bash
    pkgs.git
    pkgs.which
    pkgs.xxd
    pkgs.jq
    pkgs.toxiproxy
    pkgs.gnused
  ];

  compiler-nix-name = "ghc96";

  testnetProject = pkgsWithCrypto.haskell-nix.project {
    src = ./.;
    inherit compiler-nix-name;
    # `cooked-validators` (pulled in via testnet/cabal.project) depends on
    # packages published on CHaP rather than Hackage.
    inputMap."https://chap.intersectmbo.org/" = CHaP;
  };

  testnetExe = testnetProject.testnet.components.exes.testnet;

  # `haskell-language-server` ships two executables (`haskell-language-server`
  # and `haskell-language-server-wrapper`) but haskell.nix's `tools` mechanism
  # in `shellFor` only exposes the exe matching the tool name, so we build the
  # package ourselves (pinned to the same GHC as the project) to get both.
  hlsProject = pkgsWithCrypto.haskell-nix.hackage-package {
    name = "haskell-language-server";
    inherit compiler-nix-name;
    configureArgs = "--disable-benchmarks --disable-tests";
  };

  hlsExes = [
    hlsProject.components.exes.haskell-language-server
    hlsProject.components.exes.haskell-language-server-wrapper
  ];

  shell = testnetProject.shellFor {
    tools = {
      cabal = { };
      implicit-hie = { };
    };
    buildInputs = extraInputs ++ hlsExes;
  };

  app = pkgs.writeShellApplication {
    name = "testnet";
    runtimeInputs = extraInputs;
    runtimeEnv = {
      TESTNET_BIN = "${testnetExe}/bin/testnet";
    };
    text = builtins.readFile ./launch.sh;
  };
in

{
  devShell = shell;
  package = app;
}
