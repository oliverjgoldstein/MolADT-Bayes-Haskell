# Models and Exported Features

This repo keeps the typed molecule implementation in Haskell and consumes the
benchmark feature matrices exported by Python.

## What Lives Here

The Haskell model path is narrow:

- dataset: `freesolv_moladt_featurized`
- model: finite exact RBF Gaussian process
- inference kernels: `mh` and `lwis`

Run:

```bash
make haskell-infer-benchmark
```

or:

```bash
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
```

## What The Features Are

Python builds MolADT molecules, computes MolADT-native descriptors, and writes
standardized `X/y` matrices.

Haskell reads:

- `<prefix>_X_train.csv`
- `<prefix>_X_valid.csv`
- `<prefix>_X_test.csv`
- `<prefix>_y_train.csv`
- `<prefix>_y_valid.csv`
- `<prefix>_y_test.csv`

## What The GP Does

For FreeSolv, the Haskell GP:

- reads the Python-exported MolADT feature matrix
- screens the train split to the strongest `24` feature channels
- builds an exact RBF covariance over the finite training rows
- samples GP hyperparameters with LazyPPL
- predicts validation and test rows with posterior averaging

The model-selection branch is deliberately small:

```haskell
modelFamilyFor :: BenchmarkDataset -> BenchmarkModelFamily
modelFamilyFor dataset
  | "freesolv_" `isPrefixOf` datasetPrefix dataset
    && representationName dataset == "moladt_featurized" = UseGaussianProcessRbf
  | otherwise = UseLinearStudentT
```

The GP hyperparameters are sampled as ordinary probabilistic code:

```haskell
gaussianProcessBenchmarkModel :: GaussianProcessSupport -> Meas BenchmarkParameters
gaussianProcessBenchmarkModel support = do
  meanOffset <- sample (normal 0.0 5.0)
  logKernelScale <- sample (normal 0.0 1.0)
  logLengthScale <- sample (normal 0.0 1.0)
  logNoiseScale <- sample (normal (-1.0) 1.0)
  let params = GaussianProcessParameters
        { gpMeanOffset = meanOffset
        , gpKernelScale = exp logKernelScale
        , gpLengthScale = exp logLengthScale
        , gpNoiseScale = exp logNoiseScale
        }
  scoreLog (Exp (fromMaybe (-1.0e12) (gaussianProcessLogLikelihood support params)))
  pure (GaussianProcessPosterior params)
```

The command prints molecule counts, feature counts, selected GP features, the
draw budget, a runtime expectation, and final metrics.

## Why This Matters

MolADT gives Bayesian models an explicit typed generative state space. The
model can work with molecule fields, not just strings or plain graph labels.

Next: [Inference](inference.md), [Python interop](python-interop.md).
