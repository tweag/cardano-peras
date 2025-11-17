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
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        demo = import ./demo { inherit pkgs system; };
        demo-docker = import ./demo/docker.nix { inherit pkgs demo; };
        design = import ./design { inherit pkgs; };
      in
      {
        packages = {
          inherit
            demo
            demo-docker
            design
            ;
          default = design;
        };
        devShells = {
          inherit
            demo
            design
            ;
          default = design;
        };
      }
    );
}
