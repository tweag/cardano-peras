{
  pkgs,
  inputs,
}:
pkgs.writeShellApplication {
  name = "demo";
  runtimeInputs = with pkgs; [
    cardano-node-demo
    toxiproxy
    jq
  ];
  runtimeEnv = {
    CARDANO_NODE = "${pkgs.cardano-node-demo}/bin/cardano-node";
    STATIC_FILES = "${inputs.ouroboros-consensus}/static";
    TESTNET_ENV = ./env;
  };
  text = builtins.readFile ./launch.sh;
}
