# SMILES Scope and Validation

The SMILES support is conservative on purpose.

MolADT treats SMILES as a boundary format, not as the internal representation.

## Supported

- common bare atoms in the current examples and benchmark slice
- bracket atoms
- simple branches
- ring closures
- aromatic benzene-style lowercase syntax
- atom stereo annotations like `@` and `@@`
- directional bond annotations like `/` and `\`
- terminal hydrogen inference for supported bare atoms

## Not Supported

- the full SMILES language
- full stereochemical rendering
- arbitrary organometallic notation
- query features
- all aromatic systems

Non-classical structures can still live in MolADT as typed examples. They just
may not render back to the current SMILES subset.

## Validation

Validation checks the typed molecule after parsing. It is the gate between
boundary syntax and the internal ADT.

Use:

```bash
stack run moladtbayes -- parse-smiles "c1ccccc1"
stack run moladtbayes -- to-smiles molecules/benzene.sdf
```

Next: [Parsing and rendering](parsing.md), [Examples](examples.md).
