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

    # Demo inputs
    cardano-node.url = "github:IntersectMBO/cardano-node/peras/10.5";
    cardano-base = {
      url = "github:IntersectMBO/cardano-base?ref=5c18017546dc1032e76a985c45fe7c3df2a76616";
      flake = false;
    };
    ouroboros-network = {
      url = "github:IntersectMBO/ouroboros-network/peras/10.5";
      flake = false;
    };
    ouroboros-consensus = {
      url = "github:IntersectMBO/ouroboros-consensus/peras/10.5-with-cert-conjuring";
      flake = false;
    };
  };

  outputs =
    inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        overlays = import ./demo/overlay.nix { inherit inputs system; };
        pkgs = import inputs.nixpkgs { inherit system overlays; };
      in
      {
        packages = {
          default = import ./default.nix { inherit pkgs; };
          demo = import ./demo { inherit pkgs inputs; };
        };
        devShells.default = import ./default.nix { inherit pkgs; };
      }
    );
}
