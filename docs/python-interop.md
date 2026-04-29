# Python Interop

Haskell and Python share the MolADT molecule shape through JSON and benchmark
exports.

## Default Layout

From the Haskell repo, the sibling Python repo is expected at:

```bash
../MolADT-Bayes-Python
```

Processed benchmark exports are expected at:

```bash
../MolADT-Bayes-Python/data/processed
```

Override with:

```bash
MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed
```

## What Haskell Reads

For `freesolv_moladt_featurized`, Haskell reads:

- standardized train, validation, and test `X` matrices
- train, validation, and test `y` targets
- metadata for feature names and standardization
- committed Python FreeSolv GP artifact files for inverse design

## Ownership Boundary

Python owns:

- data downloads
- feature generation
- full benchmark runs
- figures and paper artifacts

Haskell owns:

- typed MolADT implementation
- parser and serializer behavior
- local benchmark consumer
- typed inverse-design mirror

## JSON Round Trip

```bash
stack run moladtbayes -- to-json molecules/benzene.sdf > benzene.moladt.json
stack run moladtbayes -- from-json benzene.moladt.json
```

The Haskell viewer also accepts that shared JSON boundary:

```bash
stack run moladtbayes -- view-html benzene.moladt.json --format json --output results/viewer/benzene.viewer.html
```

Next: [Models and exported features](models.md), [Inference](inference.md).
