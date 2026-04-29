# Inference

The Haskell repo is the FreeSolv benchmark consumer.

It does not own the full benchmark pipeline. Python writes the processed
feature matrices. Haskell reads them and runs a local Bayesian model.

## Main Command

```bash
make haskell-infer-benchmark
```

Direct form:

```bash
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
```

## Methods

Accepted method strings:

- `mh`
- `mh:<jitter>`
- `lwis`
- `lwis:<particles>`

Example:

```bash
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized lwis:64 128
```

The default Makefile path uses:

```text
dataset_prefix=freesolv_moladt_featurized
method=mh:0.2
row_limit=full
```

## What It Prints

Before inference starts, the command prints:

- train, validation, test, and total molecule counts
- feature count
- selected GP features
- inference method
- burn-in, posterior sample count, and draw budget
- rough runtime expectation

After inference, it prints:

- measured inference runtime
- posterior summary
- validation metrics
- per-test-row predictions
- test metrics

## Data Location

Default:

```bash
../MolADT-Bayes-Python/data/processed
```

Override:

```bash
MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed \
  stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
```

Next: [Models and exported features](models.md), [Python interop](python-interop.md).
