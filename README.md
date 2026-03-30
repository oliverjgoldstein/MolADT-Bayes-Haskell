# MolADT-Bayes-Haskell

`MolADT-Bayes-Haskell` is the typed source implementation of MolADT. It keeps the molecule representation, validation logic, orbital-aware pretty-printing, and the aligned LWIS/MH baseline that reads the Python-exported matrices.

MolADT is intended as a replacement molecular representation for bringing cheminformatics into the present day: explicit about orbitals and bonding, and less constrained by legacy graph-only assumptions.

## Molecule Representation

This repo keeps the molecule ADT directly visible: atoms, sigma bonds, and Dietz-style bonding systems.

## Orbitals

Atoms keep explicit shell and orbital structure. The CLI and pretty-printer expose that directly for small examples.

## Model

The Haskell inference side is the aligned baseline. It reads the standardized matrices exported by the Python repo and runs LWIS or MH over the linear Student-`t` model.

## Timing

The timing benchmark and the hours-long full run live in the Python repo:

- [MolADT-Bayes-Python](https://github.com/oliverjgoldstein/MolADT-Bayes-Python)

## Start Here

```bash
make haskell-build
make haskell-test
make haskell-infer-benchmark
```

The make targets wrap `stack` and can prompt to install missing local prerequisites or generate the Python-exported benchmark matrices when they are missing.

The checked-in Cabal metadata now targets `cabal-version: 2.2`, keeping the package description on a modern baseline while remaining compatible with the current Stack resolver.

## Docs

- [Docs index](docs/README.md)
- [Inference](docs/inference.md)
- [Examples](docs/examples.md)
- [CLI and demo](docs/cli-and-demo.md)
- [SMILES scope and validation](docs/smiles-scope-and-validation.md)
- [Python interop](docs/python-interop.md)

## Sibling Repo

- [MolADT-Bayes-Python](https://github.com/oliverjgoldstein/MolADT-Bayes-Python)

## License

Distributed under the MIT License. See [LICENSE](LICENSE).
