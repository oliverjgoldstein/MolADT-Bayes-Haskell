# Quickstart

This page gets you from a fresh clone to a working Haskell CLI, then points you at the Python-exported benchmark path when you are ready for aligned inference.

## 1. Build the Project

From the repo root:

```bash
make haskell-build
```

That target wraps `stack build`. If `stack` is missing and Homebrew or `apt-get` is available, the Makefile will offer to install it for you. Type `y` to allow the repair step.

If you prefer the raw command:

```bash
stack build
```

## 2. Run the Test Suite

```bash
make haskell-test
```

Equivalent raw command:

```bash
stack test
```

For the list of repo-local wrappers:

```bash
make help
```

## 3. First Parse Command

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
```

This parses an SDF file, validates it, pretty-prints the MolADT structure, and then tries to render a SMILES string.

## 4. First `parse-smiles` Command

```bash
stack run moladtbayes -- parse-smiles "c1ccccc1"
```

This parses the conservative SMILES subset, validates the structure, and pretty-prints the MolADT view.

## 5. First `to-smiles` Command

```bash
stack run moladtbayes -- to-smiles molecules/benzene.sdf
```

This loads an SDF file, validates it, and emits only the SMILES rendering.

## 6. Demo Wrapper

```bash
make haskell-demo
```

`make haskell-demo` runs `stack run moladtbayes -- demo`. The demo first parses and validates the local benzene and water examples, then runs small aligned FreeSolv and QM9 smoke benchmarks against processed exports.

By default it looks for processed exports in:

```bash
../MolADT-Bayes-Python/data/processed
```

If those processed exports are missing, the Makefile can offer to generate them from the sibling Python repo. Type `y` to let it run the matching Python benchmark helper.

## 7. Aligned Benchmark Wrapper

```bash
make haskell-infer-benchmark
```

This wrapper needs Python-exported matrices. By default it uses:

- dataset prefix: `freesolv_smiles`
- inference method: `lwis`
- row limit: `128`
- processed data dir: `../MolADT-Bayes-Python/data/processed`

If the required exported matrices are missing, the Makefile can offer to generate them from the sibling Python repo before rerunning the Haskell command.

Override the processed-data path with:

```bash
MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed stack run moladtbayes -- infer-benchmark freesolv_smiles lwis
```

For the cross-repo export contract, see [Python interop](python-interop.md).
