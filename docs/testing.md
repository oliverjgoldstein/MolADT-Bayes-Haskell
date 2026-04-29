# Testing

Run the Haskell tests with:

```bash
make haskell-test
```

That wraps:

```bash
stack test
```

## Test Suites

| Suite | Covers |
| --- | --- |
| `benchmark-alignment` | Python export loading and inverse-design smoke search |
| `edge-properties` | edge invariants |
| `parser-roundtrip` | SDF, SMILES, JSON, viewer HTML, pretty rendering, timing helpers |
| `validation-properties` | molecule validation invariants |

## Useful Smoke Checks

```bash
make haskell-build
make haskell-parse
make haskell-parse-smiles
make haskell-to-smiles
make haskell-viewer
make haskell-demo
```

## Common Failures

- Stack cannot write to its cache: rerun outside a restricted sandbox.
- Processed benchmark exports are missing: generate them in the Python repo.
- The timing corpus is missing: run the Python ZINC timing preparation first.

Next: [Quickstart](quickstart.md), [Repo map](repo-map.md).
