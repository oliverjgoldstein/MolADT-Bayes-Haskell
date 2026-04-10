# Inference

The Haskell repo is the aligned baseline. It does not own the large benchmark run or the reviewer-facing timing bundle, but it does own a local stdout parser-timing command. It reads the Python-exported matrices and runs LWIS or MH over the same standardized `X/y` format.

## Main Command

```bash
stack run moladtbayes -- infer-benchmark freesolv_moladt lwis
```

The `Makefile` wrapper is:

```bash
make haskell-infer-benchmark
```

## What It Uses

Given a dataset prefix such as `freesolv_moladt` or `qm9_moladt`, it loads:

- `<prefix>_X_train.csv`
- `<prefix>_X_valid.csv`
- `<prefix>_X_test.csv`
- `<prefix>_y_train.csv`
- `<prefix>_y_valid.csv`
- `<prefix>_y_test.csv`

The aligned benchmark contract now uses the `_moladt` exports only.

The target name comes from the exported `y_train` header.

## Inference Syntax

Accepted forms:

- `lwis`
- `lwis:<particles>`
- `mh`
- `mh:<jitter>`

Meaning:

- `lwis` uses the default particle count from `posteriorSamples`. The current default is `200`.
- `lwis:<particles>` overrides the LWIS particle count.
- `mh` uses the default jitter `0.9`.
- `mh:<jitter>` overrides the MH jitter value.

The optional final integer argument truncates each split after loading.

## Examples

```bash
stack run moladtbayes -- infer-benchmark freesolv_moladt lwis
stack run moladtbayes -- infer-benchmark qm9_moladt mh:0.9 256
```

With an explicit processed-data directory:

```bash
MOLADT_PROCESSED_DATA_DIR=../MolADT-Bayes-Python/data/processed stack run moladtbayes -- infer-benchmark qm9_moladt mh:0.9 256
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
- posterior sample count
- posterior mean intercept and sigma
- top coefficients
- validation MAE and RMSE summary
- per-row test predictions with `predicted`, `actual`, `residual`, and `posterior_sd`
- test-set MAE and RMSE summary

This is a stdout-oriented baseline. The reviewer-facing Markdown, CSV, graphs, and timing files are written by the Python repo instead, while the Haskell parser-timing command stays local and stdout-only.

## Alignment

The Haskell model is aligned to the Python `bayes_linear_student_t` exported `X/y` format:

- predictors are the exact standardized `X_train`, `X_valid`, and `X_test` matrices produced by Python
- standardization uses train-split mean and standard deviation only
- targets stay on the original scale
- the model is a linear Student-`t` regression baseline

Core Haskell model files:

- [`src/BenchmarkModel.hs`](../src/BenchmarkModel.hs) for the aligned regression model, dataset loading, and benchmark reporting
- [`src/LazyPPL.hs`](../src/LazyPPL.hs) for the `lwis` and `mh` inference kernels

For the export contract and default path, see [Python interop](python-interop.md).
