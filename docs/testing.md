# Testing

Use this page to verify the Haskell install and to understand what the current test suites cover.

## Verify the Install

From the repo root:

```bash
make haskell-build
make haskell-test
```

Equivalent raw commands:

```bash
stack build
stack test
```

For a quick self-contained CLI sanity check:

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
stack run moladtbayes -- parse-smiles "c1ccccc1"
stack run moladtbayes -- parse-smiles-csv-timing ../MolADT-Bayes-Python/data/raw/zinc/zinc15_250K_2D.csv 128
stack run moladtbayes -- to-smiles molecules/benzene.sdf
```

## Test Suites

### [`test/benchmark-alignment`](../test/benchmark-alignment/)

Checks that the Haskell side can load the Python-exported `freesolv_moladt_featurized` and `qm9_moladt_featurized` matrices and sees the expected target/representation structure.

### [`test/edge-properties`](../test/edge-properties/)

QuickCheck properties for basic Dietz edge behavior such as edge canonicalization and idempotent sigma insertion.

### [`test/parser-roundtrip`](../test/parser-roundtrip/)

Hspec tests for:

- SDF round-trips
- benzene aromatic-system detection
- conservative SMILES parsing
- CSV-field-to-String timing-path coverage for the local parser benchmark
- bracketed water and methane rendering
- deterministic benzene SMILES rendering

### [`test/validation-properties`](../test/validation-properties/)

QuickCheck properties for validator invariants, including benzene relabeling and electron accounting.

## Common Failure Cases

- Missing Stack or GHC:
  `make haskell-build` can offer to install `stack` through Homebrew or `apt-get` when one of those package managers is available.
- Missing processed data for interop:
  `make haskell-demo` and `make haskell-infer-benchmark` can offer to generate the needed exports from the sibling Python repo when `../MolADT-Bayes-Python/data/processed` is missing and `MOLADT_PROCESSED_DATA_DIR` is not set. In that delegated Python path, only downloads and extractions above GitHub's 100 MB file limit show the live meter, including byte counts, extraction entry counts, throughput, and elapsed time.
- Unsupported SMILES outside the conservative subset:
  the CLI will reject molecules outside the supported classical boundary. See [SMILES scope and validation](smiles-scope-and-validation.md).
- Confusion about which repo owns which benchmark stage:
  raw dataset download, feature export, and `results/` artifacts belong to the Python repo; Haskell consumes the exported matrices, prints its own inference summaries to stdout, and has a local stdout parser-timing command.

## Related Pages

- [Quickstart](quickstart.md)
- [CLI and demo](cli-and-demo.md)
- [Inference](inference.md)
- [Python interop](python-interop.md)
