{ pkgs ? import <nixpkgs> {} }:
let
  ghc = pkgs.haskell.packages.ghc96.ghcWithPackages
          (p: [ p.array
                p.binary
                p.bytestring
                p.containers
                p.deepseq
                p.directory
                p.filepath
                p.ghc-heap
                p.log-domain
                p.massiv
                p.math-functions
                p.megaparsec
                p.monad-extras
                p.mtl
                p.parallel
                p.random
                p.statistics
                p.text
                p.time
                p.transformers
                p.vector
              ]);
in
pkgs.mkShell {
  buildInputs = [
    ghc
    pkgs.cabal-install
    pkgs.ripgrep
    pkgs.stack
  ];
}
