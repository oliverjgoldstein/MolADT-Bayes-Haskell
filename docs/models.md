# Models and Exported Features

This page explains what the Haskell repo means by "models over molecules".

## Our Approach

The Haskell-side approach is:

- keep the MolADT source representation explicit and typed
- reuse the Python MolADT benchmark exports
- run the aligned Haskell benchmark models over those same exports
- use the Python MoleculeNet figures as the paper comparison

The short version is:

- the typed `Molecule` ADT is the source chemistry object
- Python turns typed MolADT objects into aligned numeric matrices for the benchmark run
- Haskell then runs the same probabilistic benchmark consumer over those exported matrices

## What Model Lives Here

The Haskell side does not own the full benchmark pipeline.

It owns the aligned benchmark model and inference path:

- a finite exact RBF Gaussian process for `freesolv_moladt_featurized`
- `lwis` inference
- `mh` inference

For FreeSolv, the Haskell GP is the main new model in this repo. It is not a graph neural network and it is not a dry wrapper over the Python Stan code. It is a local finite exact GP implementation that:

- starts from the Python-exported `moladt_featurized` matrix
- screens the train split down to the strongest `24` MolADT feature channels
- builds an exact RBF covariance over those rows
- learns a posterior over mean offset, kernel scale, length scale, and noise scale
- predicts with posterior averaging over those hyperparameter samples

The core implementation lives in [`src/GaussianProcess.hs`](../src/GaussianProcess.hs). The benchmark wiring that chooses this model for FreeSolv lives in [`src/BenchmarkModel.hs`](../src/BenchmarkModel.hs).

The main command is:

```bash
make haskell-infer-benchmark
```

or directly:

```bash
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
```

## Where The Features Come From

The Haskell baseline reads standardized `X/y` matrices exported by the Python repo.

For the supported dataset prefix `freesolv_moladt_featurized`, the Haskell side expects:

- `*_X_train.csv`, `*_X_valid.csv`, `*_X_test.csv`
- `*_y_train.csv`, `*_y_valid.csv`, `*_y_test.csv`

## What Those Features Represent

The current cross-repo contract is MolADT-only:

- Python builds the typed `Molecule` object
- Python computes MolADT-native descriptors from that object
- Python's current FreeSolv benchmark path uses the richer `moladt_featurized` export
- Haskell consumes the exported standardized `X/y` matrices

For FreeSolv, Haskell screens the training split down to the strongest MolADT feature channels before fitting the GP. The current cap is `24` train-selected features.

That small-data choice is deliberate. FreeSolv has too little data for a large unrestricted kernel over every exported channel, so the Haskell path narrows the GP to the strongest train-only directions before it builds the covariance matrix.

The main comparison is then MolADT versus MoleculeNet, not MolADT versus a second local representation.

## Example Code

This is the supported model-selection branch for the Haskell benchmark surface:

```haskell
modelFamilyFor :: BenchmarkDataset -> BenchmarkModelFamily
modelFamilyFor dataset
  | "freesolv_" `isPrefixOf` datasetPrefix dataset
    && representationName dataset == "moladt_featurized" = UseGaussianProcessRbf
```

And this is the start of the actual GP model used for FreeSolv:

```haskell
gaussianProcessBenchmarkModel :: GaussianProcessSupport -> Meas BenchmarkParameters
gaussianProcessBenchmarkModel support = do
  meanOffset <- sample (normal 0.0 5.0)
  logKernelScale <- sample (normal 0.0 1.0)
  logLengthScale <- sample (normal 0.0 1.0)
  logNoiseScale <- sample (normal (-1.0) 1.0)
  let params =
        GaussianProcessParameters
          { gpMeanOffset = meanOffset
          , gpKernelScale = max 1.0e-4 (exp logKernelScale)
          , gpLengthScale = max 1.0e-3 (exp logLengthScale)
          , gpNoiseScale = max 1.0e-4 (exp logNoiseScale)
          }
```

The full implementation lives in [`src/BenchmarkModel.hs`](../src/BenchmarkModel.hs) and [`src/GaussianProcess.hs`](../src/GaussianProcess.hs). The supported Haskell benchmark path is the FreeSolv exact GP branch.

## Why This Matters For The Haskell Repo

The Haskell repo keeps the typed source representation small and inspectable, then uses the aligned benchmark models to ask:

- what happens when the same MolADT descriptor matrix is pushed through a finite exact GP instead of the Python Stan path?
- how do `lwis` and `mh` behave on the same exported MolADT prediction problem?
- what happens when the same MolADT descriptor matrix is pushed through a second implementation of the local inference path?

That is why this repo has a model page even though Python owns the heavier feature pipeline: the benchmark models still depend on the typed molecular object used to generate `X`.

## Where To Read More

- [Inference](inference.md)
- [Python interop](python-interop.md)
- [`src/GaussianProcess.hs`](../src/GaussianProcess.hs)
- Python-side feature and model overview: [../../MolADT-Bayes-Python/docs/models.md](../../MolADT-Bayes-Python/docs/models.md)
