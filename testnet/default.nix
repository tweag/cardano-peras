{
  pkgs,
  system,
  nixpkgs,
  haskellNix,
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

  isAarch64Linux = system == "aarch64-linux";

  ghcFixOverlay =
    if isAarch64Linux then
      (_final: prev: {
        haskell-nix = prev.haskell-nix // {
          compiler = prev.haskell-nix.compiler // {
            ghc967 = prev.haskell-nix.compiler.ghc967.overrideAttrs (old: {
              NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -std=gnu17 -Wno-error=incompatible-pointer-types";
            });
          };
        };
      })
    else
      (_final: _prev: { });

  ghcBuildPkgs = import nixpkgs {
    inherit system;
    overlays = [
      haskellNix.overlay
      ghcFixOverlay
    ];
  };

  testnetProject = ghcBuildPkgs.haskell-nix.project {
    src = ./.;
    compiler-nix-name = "ghc96";
    modules = ghcBuildPkgs.lib.optionals isAarch64Linux [
      (
        { config, pkgs, ... }:
        {
          ghc.package =
            let
              withCachedDeps =
                ghc:
                ghc
                // {
                  cachedDeps = (pkgs.buildPackages.haskell-nix.haskellLib.makeCompilerDeps ghc).cachedDeps;
                };
              base = pkgs.buildPackages.haskell-nix.compiler.${config.compiler.nix-name}.override {
                ghcEvalPackages = config.evalPackages;
              };
            in
            withCachedDeps base // { buildGHC = withCachedDeps (base.buildGHC or base); };
        }
      )
    ];
  };

  testnetExe = testnetProject.testnet.components.exes.testnet;

  shell = testnetProject.shellFor {
    buildInputs = extraInputs ++ [ pkgs.cabal-install ];
    withHoogle = false;
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
