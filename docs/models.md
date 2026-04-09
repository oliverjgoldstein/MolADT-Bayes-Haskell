# Models and Exported Features

This page explains what the Haskell repo means by "models over molecules".

## Our Approach

The Haskell-side approach is:

- keep the MolADT source representation explicit and typed
- reuse the Python MolADT benchmark exports
- run the aligned Haskell baseline over those same exports
- use the Python MoleculeNet figures as the reviewer-facing paper comparison

The short version is:

- the typed `Molecule` ADT is the source chemistry object
- Python turns typed MolADT objects into aligned numeric matrices for the benchmark run
- Haskell then runs the same probabilistic baseline over those exported matrices

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
stack run moladtbayes -- infer-benchmark freesolv_moladt lwis
```

## Where The Features Come From

The Haskell baseline reads standardized `X/y` matrices exported by the Python repo.

For a dataset prefix such as `freesolv_moladt` or `qm9_moladt`, the Haskell side expects:

- `*_X_train.csv`, `*_X_valid.csv`, `*_X_test.csv`
- `*_y_train.csv`, `*_y_valid.csv`, `*_y_test.csv`

## What Those Features Represent

The current benchmark contract is MolADT-only:

- Python builds the typed `Molecule` object
- Python computes MolADT-native descriptors from that object
- Haskell consumes the exported standardized `X/y` matrices

The reviewer-facing comparison is then MolADT versus MoleculeNet, not MolADT versus a second local representation.

## Why This Matters For The Haskell Repo

The Haskell repo keeps the typed source representation small and inspectable, then uses the aligned baseline to ask:

- how do `lwis` and `mh` behave on the same exported MolADT prediction problem?
- what happens when the same MolADT descriptor matrix is pushed through a second implementation of the baseline inference path?

That is why this repo has a model page even though Python owns the heavier feature pipeline: the baseline still exists to model molecular data, and the comparison still depends on the typed molecular object used to generate `X`.

## Where To Read More

- [Inference baseline](inference.md)
- [Python interop](python-interop.md)
- Python-side feature and model overview: [../../MolADT-Bayes-Python/docs/models.md](../../MolADT-Bayes-Python/docs/models.md)
