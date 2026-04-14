# CLI and Demo

The main Haskell entrypoint is:

```bash
stack run moladtbayes -- --help
```

Current usage includes:

- `demo`
- `parse`
- `parse-smiles`
- `parse-sdf-timing`
- `pretty-example`
- `to-smiles`
- `infer-benchmark`

## `parse`

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
```

What it does now:

- reads the SDF file
- accepts SDF V2000 and the core V3000 CTAB subset
- validates the resulting MolADT structure
- pretty-prints the molecule
- attempts to render and print `SMILES: ...`

Use `parse` when the source of truth is a file-backed molecule.

The current V3000 support is intentionally narrow: atom coordinates, bond tables, and atom-local formal charges.

## `parse-smiles`

```bash
stack run moladtbayes -- parse-smiles "c1ccccc1"
```

What it does now:

- parses the conservative SMILES subset
- infers terminal hydrogens for supported bare atoms
- promotes recoverable six-membered delocalized cycles into explicit `pi_ring` Dietz systems when aromatic lowercase syntax is present
- preserves atom-centered `@`/`@@` and bond-directed `/` `\` annotations on `smilesStereochemistry`
- validates the resulting MolADT structure
- pretty-prints the molecule

Unlike `parse`, it does not load an SDF file and it does not print an SDF-derived title or properties block.

## `parse-sdf-timing`

```bash
stack run moladtbayes -- parse-sdf-timing ../MolADT-Bayes-Python/data/raw/zinc/zinc15_250K_2D.sdf 128
make haskell-parse-sdf-timing
```

What it does now:

- reads raw single-record SDF blocks from the normalized benchmark SDF
- times the raw SDF block read as `raw_file_read`
- times the local `SDF -> MolADT` parser as `sdf_record_parse`
- prints a small stdout report with counts, throughput, median latency, and p95 latency

This is a local parser-timing command, not the Python timing bundle.

## `pretty-example`

```bash
stack run moladtbayes -- pretty-example ferrocene
stack run moladtbayes -- pretty-example diborane
stack run moladtbayes -- pretty-example morphine
```

This command loads a named built-in Dietz example, validates it, and prints a short title/note block followed by the pretty-printed molecule. It currently supports `ferrocene`, `diborane`, and `morphine`.

## `to-smiles`

```bash
stack run moladtbayes -- to-smiles molecules/benzene.sdf
```

This command loads an SDF file, validates the structure, and prints only the SMILES rendering or the current renderer error. Stored stereochemistry annotations are preserved on parse, but the current renderer does not yet emit `@`, `@@`, `/`, or `\`.

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
  - FreeSolv / MolADT featurized with the local exact GP using MH
  - QM9 / MolADT featurized with MH

The `make haskell-demo` helper only wraps the same `demo` subcommand while setting `MOLADT_PROCESSED_DATA_DIR` from the `Makefile`.

## `infer-benchmark`

```bash
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
stack run moladtbayes -- infer-benchmark qm9_moladt_featurized mh:0.9 256
```

This command loads one Python-exported dataset prefix and runs the aligned Haskell benchmark model over it.

In the current docs story, that means:

- `freesolv_moladt_featurized` for the FreeSolv MolADT featurized export and the local exact GP
- `qm9_moladt_featurized` for the QM9 MolADT featurized export

On the FreeSolv path, the Haskell model is a finite exact RBF Gaussian process over the screened MolADT feature matrix. It screens the train split down to the strongest feature channels, then runs local LazyPPL inference over the GP hyperparameters.

## How `parse` and `parse-smiles` Differ

- `parse` starts from an SDF file on disk and then tries to render SMILES from the validated result.
- `parse-smiles` starts from a SMILES string in the conservative subset and only pretty-prints the validated MolADT structure.
- `parse-sdf-timing` starts from a benchmark SDF and compares raw block reads against the local SDF-to-MolADT parser.
- `pretty-example` starts from a built-in Dietz object rather than a file or boundary string.

## Environment Variable

The benchmark-oriented commands look for processed exports in:

```bash
MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed
```

If unset, the current default is `../MolADT-Bayes-Python/data/processed`.

## Related Files

- [`app/Main.hs`](../app/Main.hs)
- [`src/BenchmarkModel.hs`](../src/BenchmarkModel.hs)
- [`src/ExampleMolecules/Morphine.hs`](../src/ExampleMolecules/Morphine.hs)
- [`examples/ParseMolecules.hs`](../examples/ParseMolecules.hs)
