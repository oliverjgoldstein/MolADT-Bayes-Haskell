# Quickstart

This is the shortest path to a working Haskell checkout.

## Build

From `MolADT-Bayes-Haskell`:

```bash
make haskell-build
```

If Stack is missing, the Makefile explains how to install it.

## Try The CLI

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
stack run moladtbayes -- parse-smiles "c1ccccc1"
stack run moladtbayes -- pretty-example ferrocene
stack run moladtbayes -- to-smiles molecules/benzene.sdf
make haskell-viewer
```

Those commands prove that SDF parsing, SMILES parsing, built-in examples, and
SMILES rendering are wired up. The viewer command writes
`results/viewer/benzene.viewer.html`.

## Test

```bash
make haskell-test
```

## Demo

```bash
make haskell-demo
```

The demo parses local molecules and runs a small FreeSolv benchmark smoke pass.
It prints molecule counts and a rough runtime expectation before inference
starts.

## Full Benchmark Consumer

```bash
make haskell-infer-benchmark
```

This reads processed exports from the sibling Python repo:

```bash
../MolADT-Bayes-Python/data/processed
```

Override that path with:

```bash
MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed \
  stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
```

## Common Fixes

- Missing Stack: run `make haskell-build` and follow the install hint.
- Missing benchmark exports: generate them in the Python repo, then rerun.
- Unsure what command exists: run `make help`.

Next: [CLI and demo](cli-and-demo.md), [Inference](inference.md),
[Python interop](python-interop.md).
