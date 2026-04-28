# MolADT-Bayes-Haskell

Molecular modelling code often starts from strings or plain graphs, then has to recover the chemistry that was flattened away. That is a poor fit for Bayesian inference and inverse design, where the program needs to inspect and validate atoms, bonds, charges, geometry, stereochemistry, and delocalised or multicentre bonding directly.

MolADT is the typed molecule object for that job. This Haskell repo is the compact typed implementation: the chemistry object is central, notation stays at the boundary, and the same JSON representation can move between Haskell and the sibling Python benchmark repo.

[Quickstart](docs/quickstart.md) · [Representation](docs/representation.md) · [ADT Representation](docs/data-model.md) · [Models](docs/models.md) · [Examples](docs/examples.md)

## What This Repo Does

- Defines the typed MolADT molecule representation.
- Parses and validates conservative SDF and boundary-string inputs.
- Serializes the shared MolADT JSON format used by both repos.
- Consumes Python-exported benchmark matrices for the narrower Haskell FreeSolv inference path.
- Provides small examples and CLI tools for inspecting the representation.

Use this repo when you want the smaller typed reference implementation, parser/serializer behaviour, or Haskell-side inference consumer. Use the Python repo when you want the full benchmark runner, paper artifacts, feature generation, and FreeSolv inverse-design experiment.

## Why The Representation Matters

MolADT is designed for cases where ordinary graph or string encodings make the important chemistry hard to address directly:

- diborane wants explicit `3c-2e` bridge systems
- ferrocene wants shared Cp/metal bonding systems
- morphine wants fused topology and stereochemical bookkeeping available as data

MolADT keeps those decisions in typed data. That matters for inference and inverse design because models and proposal operators can work on the molecule being studied, not on a lossy boundary notation that has to be reinterpreted at every step.

## Quick Start

```bash
make haskell-build
stack run moladtbayes -- parse-smiles "c1ccccc1"
make haskell-parse-sdf-timing
```

## Parsing

Use the CLI when you want to inspect or serialize the typed MolADT object directly.

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
stack run moladtbayes -- to-json molecules/benzene.sdf > benzene.moladt.json
stack run moladtbayes -- from-json benzene.moladt.json
stack run moladtbayes -- parse-smiles "c1ccccc1"
stack run moladtbayes -- to-smiles molecules/benzene.sdf
```

- `parse` reads one SDF record, validates it, pretty-prints the MolADT structure, and then tries to render SMILES
- `to-json` reads one SDF record, validates it, and writes the shared MolADT JSON boundary format used by both repos
- `from-json` reads that MolADT JSON back into the typed Haskell `Molecule` and prints the usual MolADT report
- `parse-smiles` reads the conservative SMILES subset and lifts it into the typed MolADT object
- `to-smiles` renders validated classical MolADT structures back into the supported SMILES subset

Programmatically, the shortest `SDF -> MolADT -> JSON -> MolADT` path is:

```haskell
import Chem.IO.MoleculeJSON (moleculeFromJSON, moleculeToJSON)
import Chem.IO.SDF (readSDF)
import Chem.Molecule (atoms)
import Text.Megaparsec (errorBundlePretty)

main :: IO ()
main = do
  parsed <- readSDF "molecules/benzene.sdf"
  case parsed of
    Left err -> putStrLn (errorBundlePretty err)
    Right molecule ->
      case moleculeFromJSON (moleculeToJSON molecule) of
        Left jsonErr -> putStrLn jsonErr
        Right roundTripped -> print (length (atoms roundTripped))
```

The emitted JSON is the same MolADT boundary format used by the Python repo's `python -m moladt.cli to-json ...` and `from-json ...` commands.

The SDF parser accepts V2000 and the core V3000 CTAB subset used by ordinary structure exports:

- atom coordinates
- bond tables
- atom-local formal charges

The Haskell side is intentionally a parser, not a full MDL toolkit. It reads those structures into MolADT; it does not attempt to support the full query/enhanced-feature surface of SDF.

If one SDF file contains multiple molecules:

- read a small eager slice from disk with `case readSDFRecords "bundle.sdf" of Right ms -> take 3 ms; Left err -> error (show err)`
- parse an in-memory multi-record payload with `either (error . show) (take 3) (parseSDFRecords multiRecordText)`

The local vendored FreeSolv raw files in the sibling Python workspace are still V2000. The parser can read the core V3000 subset, but the current local benchmark raws are not being silently relabeled.

## What This Repo Contains

- the typed MolADT source implementation
- conservative SDF and SMILES boundary parsing
- a local SDF timing entry point for raw block reads versus Haskell SDF parsing
- example molecules, CLI tools, and aligned benchmark entry points

## Benchmarking

This repo does not ship precomputed benchmark results. The benchmark figures are generated by real runs from the sibling Python repo, and `results/` is meant to be populated only by those local runs.

```bash
make haskell-infer-benchmark
make haskell-parse-sdf-timing
```

The Haskell side consumes the Python-exported MolADT matrices for inference, and it can also time the local SDF parser against raw single-record SDF reads from the sibling Python cached ZINC timing corpus.

By default, `make haskell-infer-benchmark` now uses the full exported dataset splits, and `make haskell-parse-sdf-timing` targets the sibling Python `full` cached ZINC timing corpus rather than the old `128`-row smoke subset.

The local Haskell benchmark consumer uses:

- FreeSolv: a finite exact RBF Gaussian process over screened `moladt_featurized` inputs

For FreeSolv, the Haskell GP does three things:

- it starts from the Python-exported MolADT feature matrix
- it keeps the strongest `24` training-selected feature channels
- it fits a finite exact RBF kernel model and predicts from the posterior over GP hyperparameters using the local LazyPPL `mh` or `lwis` kernels

That makes the Haskell model different from the Python Stan FreeSolv path. Python uses `bayes_gp_rbf_screened` with `laplace`; Haskell uses the same MolADT-featurized export but runs a local exact GP implementation over it.

The current Python benchmark contract is:

- FreeSolv: `moladt_featurized` with `bayes_gp_rbf_screened` fit by `laplace`

The Haskell benchmark surface is intentionally narrower than the Python repo. On the Haskell side, `infer-benchmark` is now scoped to the FreeSolv export only.

The comparison figure still comes from the Python repo:

- `results/freesolv/run_.../freesolv_rmse_vs_moleculenet.svg`

That predictive comparison is deliberately narrow:

- FreeSolv compares the local MolADT RMSE to the MoleculeNet MPNN RMSE row `1.15`

Those are local benchmark artifacts, not committed front-page snapshots. The metric matches the MoleculeNet row, but the local split and Stan model family still differ from the paper.

Timing bundles still belong to the Python repo. If the sibling raw or processed files are missing, the Makefile can offer to generate them through the Python repo first. Large delegated Python-side downloads and archive extraction show live progress when the files are large enough to matter.

## Read More

- [Quickstart](docs/quickstart.md)
- [ADT representation](docs/data-model.md)
- [Parsing and rendering](docs/parsing.md)
- [CLI and demo](docs/cli-and-demo.md)
- [Models and exported features](docs/models.md)
- [Python interop](docs/python-interop.md)
- [Inference](docs/inference.md)
- [Examples](docs/examples.md)

## Related Repo

- [MolADT-Bayes-Python](https://github.com/oliverjgoldstein/MolADT-Bayes-Python)
