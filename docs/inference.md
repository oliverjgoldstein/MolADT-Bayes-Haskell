# Inference

The Haskell repo does not build the benchmark datasets itself. It consumes Python-exported train/valid/test matrices and runs an aligned linear Student-`t` regression baseline with LWIS or MH.

## Main Command

```bash
stack run moladtbayes -- infer-benchmark freesolv_smiles lwis
```

The current `Makefile` wrapper is:

```bash
make haskell-infer-benchmark
```

## What `infer-benchmark` Loads

Given a dataset prefix such as `freesolv_smiles` or `qm9_sdf`, the command loads:

- `<prefix>_X_train.csv`
- `<prefix>_X_valid.csv`
- `<prefix>_X_test.csv`
- `<prefix>_y_train.csv`
- `<prefix>_y_valid.csv`
- `<prefix>_y_test.csv`

It infers the representation from the suffix:

- `_smiles` -> `smiles`
- `_sdf` -> `sdf`

It also reads the target column name from the exported `y_train` header.

## How `datasetPrefix` Works

`datasetPrefix` is the Python export prefix, not a free-form task name.

Examples:

- `freesolv_smiles`
- `freesolv_sdf`
- `qm9_smiles`
- `qm9_sdf`

Use prefixes that already exist under the processed-data directory.

## Inference Syntax

The CLI currently accepts exactly these forms:

- `lwis`
- `lwis:<particles>`
- `mh`
- `mh:<jitter>`

What they mean at the CLI level:

- `lwis` uses likelihood-weighted importance sampling with the default particle count from `posteriorSamples`. The current default is `200`.
- `lwis:<particles>` overrides the LWIS particle count.
- `mh` uses Metropolis-Hastings with the default jitter `0.9`.
- `mh:<jitter>` overrides the MH jitter value.

The optional final integer argument truncates each split after loading.

## Practical Examples

FreeSolv / SMILES with default LWIS:

```bash
stack run moladtbayes -- infer-benchmark freesolv_smiles lwis
```

QM9 / SDF with explicit MH jitter and a row limit:

```bash
stack run moladtbayes -- infer-benchmark qm9_sdf mh:0.9 256
```

With an explicit processed-data directory:

```bash
MOLADT_PROCESSED_DATA_DIR=../MolADT-Bayes-Python/data/processed stack run moladtbayes -- infer-benchmark qm9_sdf mh:0.9 256
```

## What You Should Expect on Stdout

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

This is a stdout-oriented baseline. It does not currently write reviewer-facing Markdown or CSV files like the Python repo does.

## Alignment to the Python Export Format

The Haskell model is aligned to the Python `bayes_linear_student_t` exported `X/y` format:

- predictors are the exact standardized `X_train`, `X_valid`, and `X_test` matrices produced by Python
- standardization uses train-split mean and standard deviation only
- targets stay on the original scale
- the model is a linear Student-`t` regression baseline

For the export contract and default path, see [Python interop](python-interop.md).

## Related Files

- [`src/BenchmarkModel.hs`](../src/BenchmarkModel.hs)
- [`app/Main.hs`](../app/Main.hs)
- [`test/benchmark-alignment/Main.hs`](../test/benchmark-alignment/Main.hs)
