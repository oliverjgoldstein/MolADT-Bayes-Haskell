# Haskell Docs

This repo is the typed Haskell implementation of MolADT.

Use these pages as small entry points, not a second README.

Current representation rule: every edge lives in a bonding system. Conventional
single, double, and triple bonds are one-edge systems with 2, 4, and 6 shared
electrons; `localBonds` is the derived edge index used by traversal and legacy
callers. Pretty printing reads from the bonding systems and shows the total
electrons shared over each displayed edge; viewer output lists the same explicit
bonding systems.

## Start Here

- [Quickstart](quickstart.md): build, run, test.
- [ADT representation](data-model.md): the core molecule shape.
- [Representation](representation.md): why MolADT is more than a string or graph, including type-class group actions.
- [CLI and demo](cli-and-demo.md): command reference.
- [Examples](examples.md): benzene, water, morphine, diborane, ferrocene.
- [Molecule equality](molecule-equality.md): compare reordered MolADT values.

## Bayesian Path

- [Models and exported features](models.md): what model lives here.
- [Inference](inference.md): how the Haskell benchmark consumer runs.
- [Python interop](python-interop.md): how Haskell reads Python exports.

## Reference

- [Parsing and rendering](parsing.md)
- [SMILES scope and validation](smiles-scope-and-validation.md)
- [Orbitals](orbitals.md)
- [Molecule equality](molecule-equality.md)
- [Type classes and group actions](representation.md#type-classes-and-group-actions)
- [Repo map](repo-map.md)
- [Testing](testing.md)
