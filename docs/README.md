# Haskell Docs

The Haskell repo is the typed source implementation and the aligned baseline consumer.

## Our Approach

- keep the typed MolADT source implementation small and inspectable
- consume the Python-exported MolADT matrices
- run the aligned Haskell inference baseline over those same exports
- treat the Python MoleculeNet figures as the main comparison figures

For the shortest path, start with [Quickstart](quickstart.md). For the benchmark path, go to [Inference baseline](inference.md).

## Start Here

- [Quickstart](quickstart.md)
- [Inference baseline](inference.md)
- [Representation](representation.md)
- [Models and exported features](models.md)
- [Parsing and rendering](parsing.md)
- [Python interop](python-interop.md)

## Deeper Reference

- [Orbitals and theoretical chemistry](orbitals.md)
- [CLI and demo](cli-and-demo.md)
- [Examples](examples.md)
- [SMILES scope and validation](smiles-scope-and-validation.md)
- [Repo map](repo-map.md)
- [Testing](testing.md)
