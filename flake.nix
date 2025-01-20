{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = inputs: inputs.flake-utils.lib.eachDefaultSystem (system:
    let pkgs = inputs.nixpkgs.legacyPackages.${system}; in
    {
      packages.default = import ./default.nix { inherit pkgs; };
      devShells.default = import ./default.nix { inherit pkgs; };
    }
  );
}
