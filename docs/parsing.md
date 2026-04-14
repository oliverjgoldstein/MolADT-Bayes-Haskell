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

The SDF parser accepts:

- V2000 records
- the core V3000 CTAB subset with atom coordinates, bond tables, and atom-local formal charges

The reader is deliberately narrow. It is meant to get ordinary structure files into MolADT, not to cover the entire MDL query feature surface.

If the SDF payload contains several molecules, use `readSDFRecords "bundle.sdf"` from `Chem.IO.SDF`, or `parseSDFRecords multiRecordText` if the records are already in memory.

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

Inside that boundary, `parse-smiles` now does three lifts after reading the SMILES:

- it infers terminal hydrogens for supported bare atoms such as `C`, `N`, `O`, and aromatic lowercase atoms
- it promotes recoverable six-membered delocalized cycles into explicit Dietz `pi_ring` systems when the SMILES uses aromatic lowercase syntax, including ring-closure edges
- it preserves atom-centered `@`/`@@` and bond-directed `/` `\` annotations in `smilesStereochemistry`

The local parser is now tuned for this path: it advances through the remaining input instead of rescanning from the front, and it accumulates stereochemistry and bond-system annotations without repeated end-appends.

## If You Want the SDF Timing Baseline

Use `parse-sdf-timing`.

```bash
make haskell-parse-sdf-timing
```

Equivalent raw command:

```bash
stack run moladtbayes -- parse-sdf-timing ../MolADT-Bayes-Python/data/raw/zinc/zinc15_250K_2D.sdf 128
```

This reads the ZINC timing SDF, materializes raw single-record SDF blocks, then times the local `SDF -> MolADT` parser separately.

## If You Want SMILES Back Out

Use `to-smiles`.

```bash
make haskell-to-smiles
```

Equivalent raw command:

```bash
stack run moladtbayes -- to-smiles molecules/benzene.sdf
```

This loads an SDF file, validates it, and prints the SMILES rendering when the renderer supports that structure. The parser keeps SMILES stereochemistry flags on the MolADT object, but the current renderer does not yet synthesize those flags back out.

## SDF vs SMILES in One Sentence

- `parse` starts from a structure-backed molecule.
- `parse-smiles` starts from a compact text notation and lifts it into MolADT.

## Technical Reference

For the full command list and the demo path, see [CLI and demo](cli-and-demo.md).
