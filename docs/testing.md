# Testing

Use this page to verify the Haskell install and to understand what the current test suites cover.

## Verify the Install

From the repo root:

```bash
stack build
stack test
```

Equivalent local helper:

```bash
make haskell-test
```

For a quick self-contained CLI sanity check:

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
stack run moladtbayes -- parse-smiles "c1ccccc1"
stack run moladtbayes -- to-smiles molecules/benzene.sdf
```

## Test Suites

### [`test/benchmark-alignment`](../test/benchmark-alignment/)

Checks that the Haskell side can load the Python-exported `freesolv_smiles` and `qm9_sdf` matrices and sees the expected target/representation structure.

### [`test/edge-properties`](../test/edge-properties/)

QuickCheck properties for basic Dietz edge behavior such as edge canonicalization and idempotent sigma insertion.

### [`test/parser-roundtrip`](../test/parser-roundtrip/)

Hspec tests for:

- SDF round-trips
- benzene aromatic-system detection
- conservative SMILES parsing
- bracketed water and methane rendering
- deterministic benzene SMILES rendering

### [`test/validation-properties`](../test/validation-properties/)

QuickCheck properties for validator invariants, including benzene relabeling and electron accounting.

## Common Failure Cases

- Missing Stack or GHC:
  install a working Stack toolchain first, then rerun `stack build`.
- Missing processed data for interop:
  `demo` and `infer-benchmark` need Python-exported matrices under `../MolADT-Bayes-Python/data/processed` unless `MOLADT_PROCESSED_DATA_DIR` is set.
- Unsupported SMILES outside the conservative subset:
  the CLI will reject molecules outside the supported classical boundary. See [SMILES scope and validation](smiles-scope-and-validation.md).
- Confusion about which repo owns which benchmark stage:
  raw dataset download, feature export, and reviewer-facing `results/` artifacts belong to the Python repo; Haskell consumes the exported matrices and prints its own inference summaries to stdout.

## Related Pages

- [Quickstart](quickstart.md)
- [CLI and demo](cli-and-demo.md)
- [Inference](inference.md)
- [Python interop](python-interop.md)
