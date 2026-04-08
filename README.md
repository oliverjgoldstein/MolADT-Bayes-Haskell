# MolADT-Bayes-Haskell

This repo is the typed source implementation of MolADT.

It keeps the molecule representation, validation logic, pretty-printing, and the aligned Haskell baseline that reads the Python-exported benchmark matrices.

## Start

```bash
make haskell-build
make haskell-parse
make haskell-parse-smiles
```

If you want the aligned baseline after that:

```bash
make haskell-infer-benchmark
```

## Representation

MolADT keeps atoms, sigma bonds, and Dietz-style bonding systems explicit. Shells and orbitals remain visible in the printed structure instead of being hidden behind a reduced graph.

This repo is the smallest place to inspect the representation directly.

### SMILES vs MolADT

| Example | SMILES side | MolADT side |
| --- | --- | --- |
| Diborane | Wikipedia SMILES: `[BH2]1[H][BH2][H]1`. Standard but not faithful here: it flattens the two bridging hydrogens into ordinary graph connectivity instead of explicit `3c-2e` pools. | [`src/ExampleMolecules/Diborane.hs`](src/ExampleMolecules/Diborane.hs) stores two explicit Dietz bridge systems: `bridge_h3_3c2e` and `bridge_h4_3c2e`. |
| Ferrocene | Wikipedia SMILES: `[CH-]1C=CC=C1.[CH-]1C=CC=C1.[Fe+2]`. Standard but not faithful here: it represents ferrocene as separated ionic fragments, not the shared `eta^5` metal-ring pools we want. | [`src/ExampleMolecules/Ferrocene.hs`](src/ExampleMolecules/Ferrocene.hs) stores two Cp `pi` systems plus `fe_backdonation`. |
| Morphine | Wikipedia SMILES: `CN1CC[C@]23C4=C5C=CC(O)=C4O[C@H]2[C@@H](O)C=C[C@H]3[C@H]1C5`. This is a faithful standard boundary string for the classical graph and stereochemistry. | [`src/ExampleMolecules/Morphine.hs`](src/ExampleMolecules/Morphine.hs) stores the fused graph directly in `localBonds` and makes the delocalization explicit with `alkene_bridge` and `phenyl_pi_ring`. |

That is the intended boundary: keep what SMILES really says when it is present, and use explicit Dietz systems where SMILES would otherwise flatten or omit the chemistry.

## Parsing

The parsing story is intentionally simple.

- `make haskell-parse` starts from an SDF file.
- `make haskell-parse-smiles` starts from a SMILES string.
- `make haskell-to-smiles` renders a supported SDF-backed molecule back to SMILES.

The dedicated parsing page shows these side by side.

## Inference

The Haskell inference path is the aligned baseline, not the main high-capacity benchmark runner.

It consumes the standardized train/valid/test matrices exported by the Python repo and runs the LWIS or MH baseline over that data.

When the Haskell `Makefile` offers to generate missing exports through the sibling Python repo, large Python-side downloads and archive extractions above GitHub's 100 MB file limit show live progress.

## Read More

- [Representation](docs/representation.md)
- [Parsing and rendering](docs/parsing.md)
- [Inference baseline](docs/inference.md)
- [Python interop](docs/python-interop.md)
- [Quickstart](docs/quickstart.md)
- [CLI and demo](docs/cli-and-demo.md)

## Related Repo

- [MolADT-Bayes-Python](https://github.com/oliverjgoldstein/MolADT-Bayes-Python)
