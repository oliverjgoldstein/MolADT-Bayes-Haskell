# Haskell Docs

This repo is the compact side of MolADT. It keeps the typed representation and the aligned Haskell baseline. The timing benchmark and the full hours-long run live in the Python repo.

## Molecule Representation

Atoms, sigma bonds, and Dietz-style systems stay explicit in the core data type.

## Orbitals

Orbitals and shell structure stay visible in the pretty-printer rather than disappearing behind a reduced graph.

## Model

The Haskell model is the aligned baseline over the Python-exported train/valid/test matrices.

## Run It

```bash
stack build
stack test
make haskell-infer-benchmark
```

## Pages

- [Inference](inference.md)
- [Examples](examples.md)
- [CLI and demo](cli-and-demo.md)
- [SMILES scope and validation](smiles-scope-and-validation.md)
- [Python interop](python-interop.md)
- [Quickstart](quickstart.md)
- [Repo map](repo-map.md)
- [Testing](testing.md)

## Related Repo

- [MolADT-Bayes-Python](https://github.com/oliverjgoldstein/MolADT-Bayes-Python)
