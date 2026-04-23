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
  };

  outputs =
    {
      nixpkgs,
      haskellNix,
      flake-utils,
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
        testnet = import ./testnet/shell.nix { inherit pkgs system; };
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
          default = design;
        };
        devShells = {
          inherit
            dashboard
            demo
            design
            testnet
            ;
          default = design;
        };
      }
    );
}
