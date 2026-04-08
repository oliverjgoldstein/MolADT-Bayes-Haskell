# MolADT-Bayes-Haskell

MolADT is a typed molecular data format. This repo is the small source implementation of a representation meant to expose chemically meaningful structure and invariances instead of collapsing molecules to strings first.

Start here: [Quickstart](docs/quickstart.md)

## Example

Diborane, ferrocene, and morphine show the boundary quickly.

- diborane in standard SMILES: `[BH2]1[H][BH2][H]1`
- ferrocene in standard SMILES: `[CH-]1C=CC=C1.[CH-]1C=CC=C1.[Fe+2]`
- morphine in standard stereochemical SMILES: `CN1CC[C@]23C4=C5C=CC(O)=C4O[C@H]2[C@@H](O)C=C[C@H]3[C@H]1C5`

Those are useful boundary strings, but they are poor central representations.

- diborane wants two explicit `3c-2e` bridge systems
- ferrocene wants shared Cp/metal bonding systems, not disconnected ionic fragments
- morphine still pushes fused-ring bookkeeping and five atom-centered stereo flags into string syntax

MolADT instead keeps that chemistry in a typed core. The point of the Haskell repo is to put molecules into a format whose structure respects chemically meaningful invariances. That matters for Bayesian sampling over molecules and for models over molecular structure. SMILES is useful at the boundary, but it is notation-dependent and awkward exactly where richer chemistry matters. In the morphine example, the explicit MolADT object keeps the fused sigma graph direct and preserves the parsed SMILES stereo flags beside it.

## What This Repo Contains

- the typed MolADT source implementation
- SDF and conservative SMILES parsing and rendering
- example molecules, CLI tools, and the aligned Bayesian baseline path

For the representation itself:

- [Representation](docs/representation.md)
- [Orbitals and theoretical chemistry](docs/orbitals.md)
- [Parsing and rendering](docs/parsing.md)
- [Models and exported features](docs/models.md)

## Quick Start

```bash
make haskell-build
stack run moladtbayes -- parse-smiles "c1ccccc1"
```

## Benchmarking

The Haskell side is the aligned baseline, not the main data-prep repo.

```bash
make haskell-infer-benchmark
```

This consumes the Python-exported matrices. If they are missing, the Makefile can offer to generate them through the sibling Python repo first. Large delegated Python-side downloads and archive extraction above GitHub's 100 MB limit show byte counts, entry counts, throughput, and elapsed time.

## Read More

- [Quickstart](docs/quickstart.md)
- [CLI and demo](docs/cli-and-demo.md)
- [Models and exported features](docs/models.md)
- [Python interop](docs/python-interop.md)
- [Inference baseline](docs/inference.md)
- [Examples](docs/examples.md)

## Related Repo

- [MolADT-Bayes-Python](https://github.com/oliverjgoldstein/MolADT-Bayes-Python)
