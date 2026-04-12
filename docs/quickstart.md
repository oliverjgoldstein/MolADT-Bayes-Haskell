# Quickstart

This is the shortest path from a fresh clone to a working Haskell CLI, then to the Python-backed benchmark path.

## 1. Build

From the repo root:

```bash
make haskell-build
```

That wraps `stack build`. If `stack` is missing and Homebrew or `apt-get` is available, the Makefile can offer to install it for you.

## 2. First Successful CLI Run

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
stack run moladtbayes -- parse-smiles "c1ccccc1"
stack run moladtbayes -- parse-smiles-csv-timing ../MolADT-Bayes-Python/data/raw/zinc/zinc15_250K_2D.csv 128
stack run moladtbayes -- to-smiles molecules/benzene.sdf
```

If those commands work, the local Haskell CLI is installed correctly and the parser timing entry point can read the sibling Python CSV snapshot.

## 3. First Test Run

```bash
make haskell-test
```

Use `make help` if you want the list of repo-local wrappers.

## 4. First Demo Run

```bash
make haskell-demo
```

This is the best first end-to-end check on the Haskell side. It runs the local demo and small aligned benchmark smoke checks.

By default it looks for processed exports in:

```bash
../MolADT-Bayes-Python/data/processed
```

If those exports are missing, the Makefile can offer to generate them through the sibling Python repo.

## 5. First Aligned Benchmark Run

Before the first benchmark-backed run, install CmdStan once in the sibling Python repo:

```bash
cd ../MolADT-Bayes-Python
make python-cmdstan-install
```

Then run:

```bash
make haskell-infer-benchmark
```

This uses Python-exported matrices. By default it runs:

- dataset prefix `freesolv_moladt_featurized`
- method `lwis`
- row limit `128`

If the required exports are missing, the Makefile can offer to build them through the Python repo first. In that delegated path, Python-side downloads and large archive extractions above GitHub's 100 MB limit show byte counts, entry counts, throughput, and elapsed time.

Override the processed-data path with:

```bash
MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized lwis
```

## 6. If Setup Fails

- Missing `stack`:
  rerun `make haskell-build` and allow the offered repair step, or install `stack` yourself.
- Missing processed benchmark exports:
  let the Makefile delegate to the Python repo, or prepare them there first.
- Cross-repo benchmark contract:
  see [Python interop](python-interop.md).
