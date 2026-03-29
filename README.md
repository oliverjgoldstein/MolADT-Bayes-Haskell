# MolADT-Bayes-Haskell

`MolADT-Bayes-Haskell` is the original Haskell implementation of the MolADT chemistry model. It keeps the typed molecular ADT as the core representation, with explicit atoms, sigma adjacency, Dietz bonding systems, coordinates, validation, reactions, and lightweight SDF/SMILES boundaries.

This repository is the semantic source implementation. It can also run the aligned LWIS/MH benchmark baseline over feature matrices exported by the Python benchmark pipeline.

## Step By Step

### 1. Install GHC and Stack

The simplest route is `ghcup`, then `stack`.

If you use Nix, there is also a repository-local `shell.nix`, but it is optional.

### 2. Build and test the Haskell code

From this repository:

```bash
stack build
stack test
```

The equivalent local `make` target is:

```bash
make haskell-test
```

### 3. Try the core CLI on small examples

From this repository:

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
stack run moladtbayes -- parse-smiles "c1ccccc1"
stack run moladtbayes -- to-smiles molecules/benzene.sdf
```

These commands do not depend on any Python benchmark outputs.

### 4. Run the default Haskell demo

From this repository:

```bash
make haskell-demo
```

By default that looks for exported benchmark matrices in:

```bash
../MolADT-Bayes-Python/data/processed
```

If your exported matrices live somewhere else, set:

```bash
MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed
```

### 5. Run the aligned Haskell benchmark baseline

From this repository:

```bash
make haskell-infer-benchmark
```

That default already chooses:

- the exported `freesolv_smiles` matrix
- the `lwis` sampler
- the first `128` rows

If the exported matrices are not in the default sibling path, override it:

```bash
make haskell-infer-benchmark PROCESSED_DATA_DIR=/path/to/data/processed
```

The Haskell model is aligned to the Python `bayes_linear_student_t` benchmark family: same exported standardized `X/y` matrices, same linear regression structure, and a Student-`t` likelihood. CLI output prints `predicted`, `actual`, `residual`, and summary metrics including RMSE.

The structural representation path is available through `qm9_sdf`, where SDF/3D-derived features carry the MolADT representation advantage over a SMILES-only baseline.

### 6. Need non-default settings?

Use:

```bash
make help
stack run moladtbayes -- infer-benchmark qm9_sdf mh:0.9 256
```

Or with an explicit exported-matrix path:

```bash
MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed stack run moladtbayes -- infer-benchmark qm9_sdf mh:0.9 256
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

The larger FreeSolv, QM9, and ZINC benchmark pipeline lives in the Python repository. The aligned Haskell baseline consumes the exported matrices from that pipeline rather than recomputing them locally.

## License

Distributed under the MIT License. See [LICENSE](LICENSE).

## LazyPPL Disclaimer

The probabilistic programming components (`LazyPPL.hs` and `Distr.hs`) are taken from the [LazyPPL project](https://github.com/lazyppl-team/lazyppl) by Swaraj Dash, Younesse Kaddar, Hugo Paquet, and Sam Staton. These files were not written by us and are included here with permission.
