# MolADT-Bayes-Haskell

`MolADT-Bayes-Haskell` is the original Haskell implementation of MolADT. It preserves the typed molecular ADT, validation logic, conservative SDF/SMILES boundary, and an aligned LWIS/MH inference baseline that consumes processed benchmark exports from the Python repo.

This repo is for readers who want to inspect the Haskell source implementation, run the CLI through Stack, or compare the Haskell baseline against the Python-produced train/valid/test exports.

## Start Here

```bash
stack build
stack test
stack run moladtbayes -- parse molecules/benzene.sdf
stack run moladtbayes -- parse-smiles "c1ccccc1"
```

## Docs

- [Docs index](docs/README.md)
- [Quickstart](docs/quickstart.md)
- [Examples](docs/examples.md)
- [CLI and demo](docs/cli-and-demo.md)
- [Inference](docs/inference.md)
- [SMILES scope and validation](docs/smiles-scope-and-validation.md)
- [Repo map](docs/repo-map.md)
- [Python interop](docs/python-interop.md)
- [Testing](docs/testing.md)

## Sibling Repo

- [MolADT-Bayes-Python](https://github.com/oliverjgoldstein/MolADT-Bayes-Python)

## Notes

- The aligned benchmark matrices are produced by the Python repo and consumed here via `MOLADT_PROCESSED_DATA_DIR`.
- `LazyPPL.hs` and `Distr.hs` are vendored from the LazyPPL project; keep that provenance in mind when working in the probabilistic code path.

## License

Distributed under the MIT License. See [LICENSE](LICENSE).
