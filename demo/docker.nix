{ pkgs, demo }:
pkgs.dockerTools.buildImage {
  name = "cardano-peras-demo";
  tag = "latest";
  copyToRoot = [ demo ];
  runAsRoot = ''
    mkdir -p ./tmp
    chmod 777 ./tmp
  '';
  config.Cmd = [ "${demo}/bin/demo" ];
}
