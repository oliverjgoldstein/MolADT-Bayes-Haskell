{ pkgs ? import <nixpkgs> {} }:
let
  ghc = pkgs.haskell.packages.ghc96.ghcWithPackages
          (p: [ p.monad-extras
                p.transformers
                p.mtl
                p.deepseq
                p.containers
                p.ghc-heap
                p.megaparsec
                p.vector
                p.directory
                p.filepath
                p.bytestring
                p.text
                p.random
                p.log-domain
                p.statistics
                p.array
              ]);
in
pkgs.mkShell {
  buildInputs = [ ghc pkgs.cabal-install pkgs.ripgrep ];
}
