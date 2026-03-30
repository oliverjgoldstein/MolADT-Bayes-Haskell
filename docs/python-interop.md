# Python Interop

The Haskell repo consumes processed benchmark exports from the sibling Python repo:

- Python repo: https://github.com/oliverjgoldstein/MolADT-Bayes-Python

The large benchmark pipeline lives there. The Haskell side reads the exported matrices and runs an aligned baseline over them.

## Default Processed-Data Location

The current default path is:

```bash
../MolADT-Bayes-Python/data/processed
```

Override it with:

```bash
MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed
```

## What Haskell Expects

For a dataset prefix such as `freesolv_smiles` or `qm9_sdf`, Haskell expects:

- `*_X_train.csv`, `*_X_valid.csv`, `*_X_test.csv`
- `*_y_train.csv`, `*_y_valid.csv`, `*_y_test.csv`

These are the Python-exported aligned matrices.

## Export Contract

The important cross-repo guarantees are:

- `X_train`, `X_valid`, and `X_test` are standardized using the train-split mean and standard deviation only.
- `y_train`, `y_valid`, and `y_test` stay on the original target scale.
- the Python side is the main producer of these aligned benchmark exports.

That contract is what lets the Haskell baseline compare inference behavior without rebuilding the feature pipeline locally.

## Practical Workflow

1. In the Python repo, build or refresh the exports:

   ```bash
   ./.venv/bin/python -m scripts.run_all smoke-test
   ./.venv/bin/python -m scripts.run_all qm9 --limit 2000
   ```

2. In the Haskell repo, point at that processed-data directory:

   ```bash
   MOLADT_PROCESSED_DATA_DIR=../MolADT-Bayes-Python/data/processed stack run moladtbayes -- infer-benchmark freesolv_smiles lwis
   ```

3. For the structural QM9 path:

   ```bash
   MOLADT_PROCESSED_DATA_DIR=../MolADT-Bayes-Python/data/processed stack run moladtbayes -- infer-benchmark qm9_sdf mh:0.9 256
   ```

## Repo Ownership Boundary

Keep this split clear:

- Python owns dataset download, feature extraction, split export, Stan benchmarking, and reviewer-facing `results/` files.
- Haskell owns the typed source implementation, CLI, and the aligned LWIS/MH baseline over Python-exported matrices.

If a benchmark stage needs raw FreeSolv, QM9, or ZINC processing, it belongs on the Python side first.

## Related Files

- [`src/BenchmarkModel.hs`](../src/BenchmarkModel.hs)
- [`app/Main.hs`](../app/Main.hs)
- [`../README.md`](../README.md)
