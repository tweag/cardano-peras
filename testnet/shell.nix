{
  pkgs,
  system,
}:

let

  cardano = import ./nix/cardano.nix {
    inherit pkgs;
    inherit system;
  };

  buildInputs = [
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
  ];

  testnet = pkgs.haskell-nix.project {
    src = ./.;
    compiler-nix-name = "ghc96";
  };

in

testnet.shellFor {
  tools = {
    cabal = { };
  };

  inherit buildInputs;
}
