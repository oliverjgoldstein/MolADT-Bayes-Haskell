# MolADT-Bayes-Haskell

MolADT is a typed molecular ADT for building models over molecules without collapsing them to strings first. This repo is the small source implementation of the representation, parser, validator, and pretty-printer.

Start here: [Quickstart](docs/quickstart.md)

## Example

Standard SMILES for diborane:
`[BH2]1[H][BH2][H]1`

MolADT can keep the chemistry more directly:

- the ordinary sigma framework
- two explicit `3c-2e` bridge systems
- shells and orbitals still attached to atoms

That is the point of the Haskell repo: keep the chemistry explicit in a typed core and make that structure available to models instead of burying it in a string.

## What This Repo Contains

- the typed MolADT source implementation
- SDF and conservative SMILES parsing and rendering
- example molecules, CLI tools, and the aligned baseline path

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
