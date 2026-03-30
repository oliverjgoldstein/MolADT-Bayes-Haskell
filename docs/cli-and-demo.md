# CLI and Demo

The main Haskell entrypoint is:

```bash
stack run moladtbayes -- --help
```

Current usage includes:

- `demo`
- `parse`
- `parse-smiles`
- `to-smiles`
- `infer-benchmark`

## `parse`

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
```

What it does now:

- reads the SDF file
- validates the resulting MolADT structure
- pretty-prints the molecule
- attempts to render and print `SMILES: ...`

Use `parse` when the source of truth is a file-backed molecule.

## `parse-smiles`

```bash
stack run moladtbayes -- parse-smiles "c1ccccc1"
```

What it does now:

- parses the conservative SMILES subset
- validates the resulting MolADT structure
- pretty-prints the molecule

Unlike `parse`, it does not load an SDF file and it does not print an SDF-derived title or properties block.

## `to-smiles`

```bash
stack run moladtbayes -- to-smiles molecules/benzene.sdf
```

This command loads an SDF file, validates the structure, and prints only the SMILES rendering or the current renderer error.

## `demo`

```bash
stack run moladtbayes -- demo
make haskell-demo
```

`demo` combines two kinds of smoke coverage:

- parsing and validating `molecules/benzene.sdf`
- parsing and validating `molecules/water.sdf`
- rendering SMILES where supported
- running aligned benchmark smoke passes for:
  - FreeSolv / SMILES with LWIS
  - QM9 / SDF with MH

The `make haskell-demo` helper only wraps the same `demo` subcommand while setting `MOLADT_PROCESSED_DATA_DIR` from the `Makefile`.

## `infer-benchmark`

```bash
stack run moladtbayes -- infer-benchmark freesolv_smiles lwis
stack run moladtbayes -- infer-benchmark qm9_sdf mh:0.9 256
```

This command loads one Python-exported dataset prefix and runs the aligned Haskell baseline over it.

## How `parse` and `parse-smiles` Differ

- `parse` starts from an SDF file on disk and then tries to render SMILES from the validated result.
- `parse-smiles` starts from a SMILES string in the conservative subset and only pretty-prints the validated MolADT structure.

## Environment Variable

The benchmark-oriented commands look for processed exports in:

```bash
MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed
```

If unset, the current default is `../MolADT-Bayes-Python/data/processed`.

## Related Files

- [`app/Main.hs`](../app/Main.hs)
- [`src/BenchmarkModel.hs`](../src/BenchmarkModel.hs)
- [`examples/ParseMolecules.hs`](../examples/ParseMolecules.hs)
