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
      biblatex
      booktabs
      caption
      catchfile
      ccaption
      cleveref
      csquotes
      enumitem
      etoolbox
      euenc
      everysel
      fancyvrb
      filehook
      float
      fontspec
      framed
      fvextra
      graphics
      latexmk
      lazylist
      libertine
      lineno
      listings
      microtype
      minted
      multirow
      newtxsf
      pgf
      pgfopts
      polytable
      quotchap
      ragged2e
      scheme-basic
      setspace
      stmaryrd
      subfig
      tabulary
      tcolorbox
      titlesec
      titling
      tocloft
      todonotes
      unicode-math
      upquote
      wrapfig
      xcolor
      xetex
      xstring
      ;
  };
  py = pkgs.python3.withPackages (ps: [
    ps.ipython
    ps.scipy
    ps.matplotlib
    ps.pygments
  ]);
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
    pkgs.biber
    py
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
