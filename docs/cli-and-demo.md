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
| `parse-smiles <text>` | Parse the conservative SMILES subset into MolADT. |
| `to-smiles <sdf>` | Render validated classical MolADT structures to supported SMILES. |
| `pretty-example <name>` | Print built-in `morphine`, `diborane`, or `ferrocene`. |
| `parse-sdf-timing <path> [limit]` | Time raw SDF reads versus `SDF -> MolADT` parsing. |
| `infer-benchmark <prefix> <method> [limit]` | Run the Haskell FreeSolv benchmark consumer. |
| `inverse-design --target <value> --seed-molecule <name>` | Run the small typed FreeSolv inverse-design search. |

## Useful Runs

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
stack run moladtbayes -- to-json molecules/benzene.sdf > benzene.moladt.json
stack run moladtbayes -- from-json benzene.moladt.json
stack run moladtbayes -- parse-smiles "c1ccccc1"
stack run moladtbayes -- pretty-example diborane
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
stack run moladtbayes -- inverse-design --target -5.0 --seed-molecule water
```

## Verbose Benchmark Output

The benchmark and inverse-design commands print:

- molecule counts before the expensive work starts
- feature counts and selected GP features
- inference or proposal budget
- rough runtime expectation
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
