{
  nixConfig = {
    extra-substituters = [
      "https://cache.iog.io"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    ];
    allow-import-from-derivation = true;
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    haskellNix.url = "github:input-output-hk/haskell.nix";
    CHaP.url = "github:IntersectMBO/cardano-haskell-packages?ref=repo";
    CHaP.flake = false;
    # Provides the libsodium-vrf/libblst/secp256k1 overlays and the
    # associated haskell.nix pkg-config mappings, required to build
    # cooked-validators' cardano dependencies.
    iohkNix.url = "github:input-output-hk/iohk-nix";
  };

  outputs =
    {
      nixpkgs,
      haskellNix,
      flake-utils,
      CHaP,
      iohkNix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ haskellNix.overlay ];
        };

        dashboard = import ./dashboard { inherit pkgs; };
        demo = import ./demo { inherit pkgs system; };
        testnet = import ./testnet { inherit pkgs system CHaP iohkNix; };
        demo-docker = import ./demo/docker.nix { inherit pkgs demo; };
        design = import ./design { inherit pkgs; };
      in
      {
        packages = {
          inherit
            dashboard
            demo
            demo-docker
            design
            ;
          testnet = testnet.package;
          default = design;
        };
        devShells = {
          inherit
            dashboard
            demo
            design
            ;
          testnet = testnet.devShell;
          default = design;
        };
      }
    );
}
