{
  pkgs,
}:
let
  # Precomputed hash for the pnpm dependencies. Needs to be updated when
  # dependencies change. The easiest way is to replace it with:
  # `pkgs.lib.fakeHash` and run `nix-build` to get the actual hash.
  hash = "sha256-xXIZlW2E5U1u3d4xGcJr6c/hGNxL+y6tmFJzg8aI5i4=";
in
pkgs.stdenv.mkDerivation (final: {
  pname = "dashboard";
  version = "0.1.0";
  src =
    with pkgs.lib.fileset;
    toSource {
      root = ./.;
      fileset = gitTracked ./.;
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
    inherit hash;
  };
  buildPhase = ''
    runHook preBuild
    pnpm run lint
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
