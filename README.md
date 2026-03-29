# MolADT-Bayes-Haskell

`MolADT-Bayes-Haskell` is the original Haskell implementation of the MolADT chemistry model. It keeps the typed molecular ADT as the core representation, with explicit atoms, sigma adjacency, Dietz bonding systems, coordinates, validation, reactions, and lightweight SDF/SMILES boundaries.

This repository is the semantic source implementation. The Python workspace companion carries the larger benchmark pipeline, while this code remains the main reference for the MolADT structure itself.

## Default Path

From the workspace root, use these commands exactly as written first. They already use the default settings.

- `make haskell-test`  
  Run the Haskell test suites.
- `make haskell-demo`  
  Run the default Haskell demo executable.
- `make haskell-infer-benchmark`  
  Run the aligned Haskell benchmark baseline with its default dataset and sampler settings.
- `make showcase`  
  Run the shared workspace bundle so the Haskell and Python surfaces are exercised together.
- `make help`  
  Show the smaller set of optional commands and overrides.

Most Haskell readers only need `make haskell-demo`.

## Standalone Usage

Install GHC and Stack with `ghcup`, then from this directory run:

```bash
stack build
stack test
```

The simplest direct CLI commands are:

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
stack run moladtbayes -- parse-smiles "c1ccccc1"
stack run moladtbayes -- to-smiles molecules/benzene.sdf
stack run moladtbayes -- demo
```

## Aligned Benchmark Baseline

The default aligned benchmark command is:

```bash
make haskell-infer-benchmark
```

That default already chooses:

- the exported `freesolv_smiles` matrix
- the `lwis` sampler
- the first `128` rows

The Haskell model is aligned to the Python `bayes_linear_student_t` benchmark family: same exported standardized `X/y` matrices, same linear regression structure, and a Student-`t` likelihood. CLI output prints `predicted`, `actual`, `residual`, and summary metrics including RMSE.

The structural representation path is available through `qm9_sdf`, where SDF/3D-derived features carry the MolADT representation advantage over a SMILES-only baseline. If you later need non-default settings, use `make help` from the workspace root or run an explicit command such as:

```bash
stack run moladtbayes -- infer-benchmark qm9_sdf mh:0.9 256
```

## SMILES Scope

The SMILES boundary is intentionally lightweight and conservative. It supports:

- atoms and bracket atoms
- bracket hydrogens and formal charges
- branches and ring digits `1-9`
- single, double, and triple bonds
- benzene-style aromatic input such as `c1ccccc1`

It does not try to encode non-classical multicenter systems like diborane or ferrocene as SMILES. Those molecules remain representable in the MolADT core, but `to-smiles` rejects structures outside the supported classical subset.

## Relation To The Python Benchmark

The larger FreeSolv, QM9, and ZINC benchmark pipeline lives in `../MolADT-Bayes-Python`. The exported matrices used by the Haskell aligned baseline are written under `../MolADT-Bayes-Python/data/processed/`, and the fitted Python reports are written under `../MolADT-Bayes-Python/results/`.

## License

Distributed under the MIT License. See [LICENSE](LICENSE).

## LazyPPL Disclaimer

The probabilistic programming components (`LazyPPL.hs` and `Distr.hs`) are taken from the [LazyPPL project](https://github.com/lazyppl-team/lazyppl) by Swaraj Dash, Younesse Kaddar, Hugo Paquet, and Sam Staton. These files were not written by us and are included here with permission.
