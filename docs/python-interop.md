# Python Interop

The Haskell repo consumes processed benchmark exports from the sibling Python repo:

- Python repo: https://github.com/oliverjgoldstein/MolADT-Bayes-Python

The large benchmark pipeline lives there. The Haskell side reads the exported matrices and runs aligned benchmark models over them.

Simple version:

- Python builds the MolADT benchmark matrices
- Python writes the MoleculeNet comparison figures
- Haskell reads the same MolADT matrices and runs the aligned local benchmark models
- both repos now share the same `Molecule <-> JSON` boundary format through `to-json` and `from-json`

For the direct structure boundary, these commands are intentionally symmetric:

```bash
cd ../MolADT-Bayes-Python
./.venv/bin/python -m moladt.cli to-json molecules/benzene.sdf > /tmp/benzene.moladt.json

cd ../MolADT-Bayes-Haskell
stack run moladtbayes -- from-json /tmp/benzene.moladt.json
```

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

For the supported Haskell dataset prefix `freesolv_moladt_featurized`, Haskell expects:

- `*_X_train.csv`, `*_X_valid.csv`, `*_X_test.csv`
- `*_y_train.csv`, `*_y_valid.csv`, `*_y_test.csv`

These are the Python-exported aligned matrices.

## Export Contract

The important cross-repo guarantees are:

- `X_train`, `X_valid`, and `X_test` are standardized using the train-split mean and standard deviation only.
- `y_train`, `y_valid`, and `y_test` stay on the original target scale.
- the Python side is the main producer of these aligned benchmark exports.

That contract is what lets the Haskell side compare inference behavior without rebuilding the feature pipeline locally.

## Practical Workflow

1. In the Python repo, build or refresh the export:

   ```bash
   make freesolv
   ```

2. In the Haskell repo, point at that processed-data directory:

   ```bash
   MOLADT_PROCESSED_DATA_DIR=../MolADT-Bayes-Python/data/processed stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
   ```

## Repo Ownership Boundary

Keep this split clear:

- Python owns dataset download, feature extraction, split export, Stan benchmarking, and `results/` files.
- Haskell owns the typed source implementation, CLI, and the aligned local FreeSolv GP path over Python-exported matrices.

If a benchmark stage needs raw FreeSolv or ZINC processing, it belongs on the Python side first.

## Related Files

- [`src/BenchmarkModel.hs`](../src/BenchmarkModel.hs)
- [`app/Main.hs`](../app/Main.hs)
- [`../README.md`](../README.md)
