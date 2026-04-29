# Repo Map

This page documents the current Haskell repo layout as it exists today.

## Top-Level Areas

### [`app/Main.hs`](../app/Main.hs)

The main CLI entrypoint. It dispatches `demo`, `parse`, `parse-smiles`, `parse-sdf-timing`, `pretty-example`, `to-smiles`, and `infer-benchmark`.

### [`examples/ParseMolecules.hs`](../examples/ParseMolecules.hs)

A small standalone example program that parses and validates the local benzene and water SDF files before pretty-printing them.

### [`molecules/`](../molecules/)

Local file-backed examples:

- `benzene.sdf`
- `water.sdf`

### [`src/Chem/`](../src/Chem/)

Core chemistry modules:

- molecule and pretty-printing logic
- SDF parsing
- conservative SMILES parsing and rendering
- local SDF timing helpers
- validation

### [`src/ExampleMolecules/`](../src/ExampleMolecules/)

Built-in MolADT example objects:

- benzene
- diborane
- ferrocene
- morphine

### [`src/BenchmarkModel.hs`](../src/BenchmarkModel.hs)

The aligned Haskell benchmark consumer. It loads the Python-exported FreeSolv matrix, parses the inference syntax, runs the local exact GP path, and prints metrics and predictions to stdout.

### [`test/`](../test/)

Test suites split by concern:

- `benchmark-alignment`
- `edge-properties`
- `parser-roundtrip`
- `validation-properties`

### [`docs/`](./)

GitHub-native documentation for setup, CLI use, aligned inference, SMILES scope, interop, and troubleshooting.
