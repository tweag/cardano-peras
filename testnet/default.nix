{
  pkgs,
  system,
}:

let

  cardano = import ./nix/cardano.nix {
    inherit pkgs;
    inherit system;
  };

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

  testnetProject = pkgs.haskell-nix.project {
    src = ./.;
    compiler-nix-name = "ghc96";
  };

  testnetExe = testnetProject.testnet.components.exes.testnet;

  shell = testnetProject.shellFor {
    tools = {
      cabal = { };
    };
    buildInputs = extraInputs;
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
