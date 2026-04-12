# Inference

The Haskell repo is the aligned benchmark consumer. It does not own the large benchmark run or the Python timing bundle, but it does own a local stdout parser-timing command. It reads the Python-exported matrices and runs local benchmark models over the same standardized `X/y` format.

## Main Command

```bash
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
```

The `Makefile` wrapper is:

```bash
make haskell-infer-benchmark
```

## What It Uses

Given a dataset prefix such as `freesolv_moladt_featurized` or `qm9_moladt_featurized`, it loads:

- `<prefix>_X_train.csv`
- `<prefix>_X_valid.csv`
- `<prefix>_X_test.csv`
- `<prefix>_y_train.csv`
- `<prefix>_y_valid.csv`
- `<prefix>_y_test.csv`

The aligned Haskell consumer currently uses the Python `freesolv_moladt_featurized` export for FreeSolv and `qm9_moladt_featurized` for QM9.

The target name comes from the exported `y_train` header.

Model selection is dataset-specific:

- `freesolv_moladt_featurized` uses a finite exact RBF Gaussian process over a train-screened subset of the MolADT featurized matrix
- `qm9_moladt_featurized` uses the local linear Student-`t` regression baseline

For FreeSolv, that GP is a real local model rather than a thin adapter. It screens the train split to the strongest `24` MolADT feature channels, builds an exact covariance matrix over the finite exported rows, and then uses local LazyPPL inference over the GP hyperparameters before predicting on validation and test.

## Inference Syntax

Accepted forms:

- `lwis`
- `lwis:<particles>`
- `mh`
- `mh:<jitter>`

Meaning:

- `lwis` uses the default particle count from `posteriorSamples`. The current default is `200`.
- `lwis:<particles>` overrides the LWIS particle count.
- `mh` uses the default site-mutation probability `0.9`.
- `mh:<jitter>` overrides the MH site-mutation probability.

The optional final integer argument truncates each split after loading.

## Examples

```bash
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
stack run moladtbayes -- infer-benchmark qm9_moladt_featurized mh:0.9 256
```

With an explicit processed-data directory:

```bash
MOLADT_PROCESSED_DATA_DIR=../MolADT-Bayes-Python/data/processed stack run moladtbayes -- infer-benchmark qm9_moladt_featurized mh:0.9 256
```

## What You See

The command prints:

- benchmark dataset prefix
- target name
- representation
- feature count
- split sizes
- model-alignment note
- inference-method description
- execution budget
- posterior sample count
- posterior hyperparameter summary for GP runs
- posterior coefficient summary for linear runs
- validation MAE and RMSE summary
- per-row test predictions with `predicted`, `actual`, `residual`, and `posterior_sd`
- test-set MAE and RMSE summary

This is a stdout-oriented benchmark consumer. The Markdown, CSV, graphs, and timing files are written by the Python repo instead, while the Haskell parser-timing command stays local and stdout-only.

## Alignment

The Haskell models are aligned to the Python exported `X/y` format:

- predictors are the exact standardized `X_train`, `X_valid`, and `X_test` matrices produced by Python
- standardization uses train-split mean and standard deviation only
- targets stay on the original scale
- FreeSolv uses an exact RBF Gaussian process adapted from the LazyPPL GP design to finite exported feature rows
- QM9 keeps the linear Student-`t` regression baseline because exact GP inference is not practical at the full QM9 training size

Core Haskell model files:

- [`src/BenchmarkModel.hs`](../src/BenchmarkModel.hs) for dataset loading, model selection, and benchmark reporting
- [`src/GaussianProcess.hs`](../src/GaussianProcess.hs) for the finite exact GP implementation
- [`src/LazyPPL.hs`](../src/LazyPPL.hs) for the `lwis` and `mh` inference kernels

For the export contract and default path, see [Python interop](python-interop.md).
