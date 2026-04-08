# Models and Exported Features

This page explains what the Haskell repo means by "models over molecules".

The short version is:

- the typed MolADT is the source chemistry object
- the Haskell repo provides an aligned probabilistic baseline
- that baseline consumes feature matrices exported by the Python repo

## What Model Lives Here

The Haskell side does not own the full benchmark pipeline.

It owns the aligned baseline model and inference path:

- linear Student-`t` regression baseline
- `lwis` inference
- `mh` inference

The main command is:

```bash
make haskell-infer-benchmark
```

or directly:

```bash
stack run moladtbayes -- infer-benchmark freesolv_smiles lwis
```

## Where The Features Come From

The Haskell baseline reads standardized `X/y` matrices exported by the Python repo.

That means the feature engineering happens on the Python side first, and Haskell then runs aligned inference over the same representation-derived inputs.

For a dataset prefix such as `freesolv_smiles` or `qm9_sdf`, the Haskell side expects:

- `*_X_train.csv`, `*_X_valid.csv`, `*_X_test.csv`
- `*_y_train.csv`, `*_y_valid.csv`, `*_y_test.csv`

## What Those Features Represent

At a high level, the exported features come from molecule representations such as:

- `smiles`
- `moladt`
- `moladt_typed`
- geometry-aware branches built on top of those molecule objects

The important point is that the MolADT-backed branches are derived from explicit molecule structure rather than from a serializer-oriented string alone.

On the Python side, that includes feature families such as:

- atom and bond summaries
- bonding-system summaries
- typed pair channels
- radial distance channels
- bond-angle channels
- torsion channels

So when this repo says it runs models over molecules, the idea is not "text in, numbers out". The model is meant to sit on top of representation-derived molecular structure.

## Why This Matters For The Haskell Repo

The Haskell repo keeps the typed source representation small and inspectable, then uses the aligned baseline to ask:

- what happens when the same feature matrices are used with a typed probabilistic implementation?
- how do `lwis` and `mh` behave on the same molecular prediction problem?

That is why this repo has a model page even though Python owns the heavy feature pipeline: the baseline still exists to model molecular data, and the features still come from molecular structure.

## Where To Read More

- [Inference baseline](inference.md)
- [Python interop](python-interop.md)
- Python-side feature and model overview: [../../MolADT-Bayes-Python/docs/models.md](../../MolADT-Bayes-Python/docs/models.md)
