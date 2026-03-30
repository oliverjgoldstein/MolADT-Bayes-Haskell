# Haskell Docs

This repo is the Haskell side of MolADT. It is the original typed source implementation and the home of the aligned LWIS/MH baseline that reads standardized benchmark exports from the Python repo.

## Most Common Tasks

| Task | Page | Command |
| --- | --- | --- |
| Build and test the repo | [Quickstart](quickstart.md) | `stack build && stack test` |
| Parse an SDF file | [CLI and demo](cli-and-demo.md) | `stack run moladtbayes -- parse molecules/benzene.sdf` |
| Parse a conservative SMILES string | [CLI and demo](cli-and-demo.md) | `stack run moladtbayes -- parse-smiles "c1ccccc1"` |
| Render an SDF-backed molecule to SMILES | [CLI and demo](cli-and-demo.md) | `stack run moladtbayes -- to-smiles molecules/benzene.sdf` |
| Run the demo flow | [CLI and demo](cli-and-demo.md) | `make haskell-demo` |
| Run aligned inference on Python exports | [Inference](inference.md) | `make haskell-infer-benchmark` |
| Check the conservative SMILES boundary | [SMILES scope and validation](smiles-scope-and-validation.md) | `stack run moladtbayes -- parse-smiles "c1ccccc1"` |
| Understand where code lives | [Repo map](repo-map.md) | `rg --files app src test examples` |
| Point Haskell at Python exports | [Python interop](python-interop.md) | `MOLADT_PROCESSED_DATA_DIR=... stack run moladtbayes -- infer-benchmark freesolv_smiles lwis` |
| Understand the tests | [Testing](testing.md) | `make haskell-test` |

## Pages

- [Quickstart](quickstart.md)
- [Examples](examples.md)
- [CLI and demo](cli-and-demo.md)
- [Inference](inference.md)
- [SMILES scope and validation](smiles-scope-and-validation.md)
- [Repo map](repo-map.md)
- [Python interop](python-interop.md)
- [Testing](testing.md)

## Related Repo

- [MolADT-Bayes-Python](https://github.com/oliverjgoldstein/MolADT-Bayes-Python)
