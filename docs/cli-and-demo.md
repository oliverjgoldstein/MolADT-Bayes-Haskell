# CLI and Demo

Run the main CLI with:

```bash
stack run moladtbayes -- --help
```

## Commands

| Command | Use it for |
| --- | --- |
| `demo` | Parse local examples and run a small FreeSolv smoke benchmark. |
| `parse <sdf>` | Read one SDF record, validate it, print the MolADT report, then try SMILES. |
| `to-json <sdf>` | Convert validated SDF input to shared MolADT JSON. |
| `from-json <json>` | Decode MolADT JSON and print the typed molecule. |
| `view-html <sdf-or-json>` | Write a standalone HTML viewer for SDF or MolADT JSON. |
| `view-examples` | Write one viewer page containing the built-in Haskell molecules. |
| `parse-smiles <text>` | Parse the conservative SMILES subset into MolADT. |
| `to-smiles <sdf>` | Render validated classical MolADT structures to supported SMILES. |
| `pretty-example <name>` | Print built-in `morphine`, `diborane`, or `ferrocene`; add `--viewer-output` to export HTML. |
| `infer-benchmark <prefix> <method> [limit]` | Run the Haskell FreeSolv benchmark consumer. |
| `inverse-design --target <value> --seed-molecule <name>` | Run the small typed FreeSolv inverse-design search. |

## Useful Runs

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
stack run moladtbayes -- to-json molecules/benzene.sdf > benzene.moladt.json
stack run moladtbayes -- from-json benzene.moladt.json
stack run moladtbayes -- view-html molecules/benzene.sdf --output results/viewer/benzene.viewer.html
stack run moladtbayes -- view-html benzene.moladt.json --format json --output results/viewer/benzene.viewer.html
stack run moladtbayes -- view-examples --output results/viewer/haskell-examples.viewer.html
stack run moladtbayes -- parse-smiles "c1ccccc1"
stack run moladtbayes -- pretty-example diborane --viewer-output results/viewer/diborane.viewer.html
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
stack run moladtbayes -- inverse-design --target -5.0 --seed-molecule water
```

## Viewer

The viewer is a single HTML file with the MolADT payload embedded. It shows
atoms, sigma edges, explicit bonding systems, axes, 3D edge lengths, stored
bond angles, atom coordinates, and shell/orbital counts. It can also load the
shared MolADT JSON files by drag and drop.

```bash
make view
make haskell-viewer
make haskell-viewer VIEWER_INPUT=molecules/water.sdf VIEWER_OUTPUT=results/viewer/water.viewer.html
make molecule-viewer
```

Use `OPEN_VIEWER=1` if you want the Make target to ask the operating system to
open the generated file.

## Verbose Benchmark Output

The benchmark and inverse-design commands print:

- molecule counts before the expensive work starts
- feature counts and selected GP features
- inference or proposal budget
- measured runtime once the search or inference completes

This keeps long Bayesian tasks from looking silent.

## Environment

Benchmark commands read processed Python exports from:

```bash
MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed
```

If unset, the default is:

```bash
../MolADT-Bayes-Python/data/processed
```

Next: [Parsing and rendering](parsing.md), [Inference](inference.md),
[Examples](examples.md).
