{
  pkgs,
}:
let
  fs = pkgs.lib.fileset;
in
pkgs.stdenv.mkDerivation (final: {
  pname = "dashboard";
  version = "0.1.0";
  src = fs.toSource {
    root = ./.;
    fileset = fs.gitTracked ./.;
  };
  nativeBuildInputs = [
    pkgs.pnpm
    pkgs.pnpm.configHook
    pkgs.nodejs
    pkgs.vue-language-server
  ];
  shellHook = ''
    export PATH=$(pnpm bin):$PATH
    pnpm install @vue/cli
  '';
  pnpmDeps = pkgs.pnpm.fetchDeps {
    inherit (final) pname version src;
    hash = "sha256-HanswtTXf8ZnEN4ClgXflIdFFVin79LTGS3X3SMgpsY=";
  };
  buildPhase = ''
    runHook preBuild
    pnpm build
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r dist/* $out
    runHook postInstall
  '';
})
