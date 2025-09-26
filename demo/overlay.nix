{
  inputs,
  system,
}:
[
  # Overlay to build cardano-node from the demo branch with necessary dependencies
  (_: _: {
    cardano-node-demo =
      let
        packageOverrides = ''
          packages:
            ${inputs.cardano-base}/cardano-base

          packages:
            ${inputs.ouroboros-network}/ouroboros-network
            ${inputs.ouroboros-network}/ouroboros-network-api
            ${inputs.ouroboros-network}/ouroboros-network-framework
            ${inputs.ouroboros-network}/ouroboros-network-mock
            ${inputs.ouroboros-network}/ouroboros-network-protocols

          packages:
            ${inputs.ouroboros-consensus}/ouroboros-consensus
            ${inputs.ouroboros-consensus}/ouroboros-consensus-cardano
            ${inputs.ouroboros-consensus}/ouroboros-consensus-protocol
            ${inputs.ouroboros-consensus}/ouroboros-consensus-diffusion
        '';
        ghcOptions = [ "-Wwarn" ];
        patchedProject = inputs.cardano-node.project.${system}.appendModule {
          cabalProjectLocal = packageOverrides;
          modules = [ { inherit ghcOptions; } ];
          # ^ workaround for https://github.com/input-output-hk/haskell.nix/issues/1149
        };
      in
      patchedProject.hsPkgs.cardano-node.components.exes.cardano-node;
  })
]
