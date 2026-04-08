# MolADT-Bayes-Haskell

This repo is the typed source implementation of MolADT.

It keeps the molecule representation, validation logic, pretty-printing, and the aligned Haskell baseline that reads the Python-exported benchmark matrices.

## Start

```bash
make haskell-build
make haskell-parse
make haskell-parse-smiles
```

If you want the aligned baseline after that:

```bash
make haskell-infer-benchmark
```

## Representation

MolADT keeps atoms, sigma bonds, and Dietz-style bonding systems explicit. Shells and orbitals remain visible in the printed structure instead of being hidden behind a reduced graph.

This repo is the smallest place to inspect the representation directly.

## Parsing

The parsing story is intentionally simple.

- `make haskell-parse` starts from an SDF file.
- `make haskell-parse-smiles` starts from a SMILES string.
- `make haskell-to-smiles` renders a supported SDF-backed molecule back to SMILES.

The dedicated parsing page shows these side by side.

## Inference

The Haskell inference path is the aligned baseline, not the main high-capacity benchmark runner.

It consumes the standardized train/valid/test matrices exported by the Python repo and runs the LWIS or MH baseline over that data.

When the Haskell `Makefile` offers to generate missing exports through the sibling Python repo, large Python-side downloads and archive extractions above GitHub's 100 MB file limit show live progress.

## Read More

- [Parsing and rendering](docs/parsing.md)
- [Inference baseline](docs/inference.md)
- [Python interop](docs/python-interop.md)
- [Quickstart](docs/quickstart.md)
- [CLI and demo](docs/cli-and-demo.md)

## Related Repo

- [MolADT-Bayes-Python](https://github.com/oliverjgoldstein/MolADT-Bayes-Python)
