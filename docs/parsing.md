# Parsing and Rendering

This is the shortest way to see the typed MolADT implementation directly.

## If You Have an SDF File

Use `parse`.

```bash
make haskell-parse
```

Equivalent raw command:

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
```

This parses the file-backed molecule, validates it, pretty-prints the MolADT structure, and then tries to render SMILES from the validated result.

## If You Have a SMILES String

Use `parse-smiles`.

```bash
make haskell-parse-smiles
```

Equivalent raw command:

```bash
stack run moladtbayes -- parse-smiles "c1ccccc1"
```

This parses the conservative SMILES subset, validates it, and pretty-prints the MolADT structure.

## If You Want SMILES Back Out

Use `to-smiles`.

```bash
make haskell-to-smiles
```

Equivalent raw command:

```bash
stack run moladtbayes -- to-smiles molecules/benzene.sdf
```

This loads an SDF file, validates it, and prints the SMILES rendering when the renderer supports that structure.

## SDF vs SMILES in One Sentence

- `parse` starts from a structure-backed molecule.
- `parse-smiles` starts from a compact text notation and lifts it into MolADT.

## Technical Reference

For the full command list and the demo path, see [CLI and demo](cli-and-demo.md).
