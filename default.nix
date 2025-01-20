{ pkgs ? import <nixpkgs> { } }:

let
  fs = pkgs.lib.fileset;
  fontsConf = pkgs.makeFontsConf {
    fontDirectories = [ ./tex/latex/fonts ];
  };
  texlive = pkgs.texlive.combine {
    inherit (pkgs.texlive)
      amsmath
      appendix
      bera
      booktabs
      caption
      catchfile
      ccaption
      cleveref
      euenc
      enumitem
      etoolbox
      everysel
      filehook
      framed
      float
      fontspec
      fvextra
      fancyvrb
      graphics
      latexmk
      lazylist
      libertine
      lineno
      listings
      microtype
      multirow
      minted
      newtxsf
      pgf
      pgfopts
      polytable
      quotchap
      ragged2e
      scheme-basic
      stmaryrd
      setspace
      subfig
      tabulary
      titlesec
      titling
      tocloft
      todonotes
      unicode-math
      upquote
      wrapfig
      xcolor
      xstring
      xetex
      ;
  };
in
pkgs.stdenv.mkDerivation {
  name = "main";
  src = fs.toSource {
    root = ./.;
    fileset = fs.union ./design ./tex;
  };
  env.FONTCONFIG_FILE = "${fontsConf}";
  buildInputs = [
    pkgs.haskellPackages.lhs2tex
    pkgs.fontconfig
    texlive
    pkgs.python3Packages.pygments
    pkgs.ripgrep
    pkgs.which
  ];
  shellHook = ''
    export TEXMFHOME=$(pwd):$TEXMFHOME
  '';

  buildPhase = ''
    runHook preBuild
    export TEXMFHOME=$PWD
    cd ./design
    latexmk peras-design.tex
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp peras-design.pdf $out/
    runHook postInstall
  '';
}
