# MolADT Representation

MolADT is a molecule representation designed to stay explicit where SMILES is compressed.

## What Stays Explicit

MolADT keeps:

- atoms with coordinates
- localized sigma bonds
- Dietz-style bonding systems for delocalized and multicenter structure
- shell and orbital information on atoms

The core object is a molecule, not a serialization.

## Why This Matters

SMILES is useful at the boundary, but it is still a renderer-oriented string syntax.

- ring closures are written indirectly through digits
- delocalization is expressed through shorthand conventions
- geometry is not the center of the representation
- richer bonding has to be approximated or pushed somewhere else

MolADT keeps the chemistry object first and treats SMILES as one boundary format among several.

## Concrete Examples

Diborane and ferrocene show the non-classical side of the story: the built-in examples keep multicenter bridges and metal-centered pools explicit even though the current classical SMILES renderer does not support them.

Standard boundary notation already compresses both:

```text
[BH2]1[H][BH2][H]1
[CH-]1C=CC=C1.[CH-]1C=CC=C1.[Fe+2]
```

Those are useful SMILES strings, but they flatten the diborane bridges and split ferrocene into ionic fragments instead of the explicit multicenter pools used in MolADT.

Morphine shows the classical fused-ring side more clearly.

The standard stereochemical boundary string is:

```text
CN1CC[C@]23C4=C5C=CC(O)=C4O[C@H]2[C@@H](O)C=C[C@H]3[C@H]1C5
```

That string is faithful for the classical graph, but it still compresses the fused skeleton into ring digits, localized double-bond syntax, and atom-centered `@`/`@@` flags.

In the explicit built-in morphine example at [`src/ExampleMolecules/Morphine.hs`](../src/ExampleMolecules/Morphine.hs), the five classical ring-closure edges from the standard sketch are just ordinary entries in `localBonds`:

- `O#1 ↔ C#11`
- `C#2 ↔ C#8`
- `C#7 ↔ C#18`
- `C#9 ↔ C#21`
- `C#10 ↔ C#16`

The example then uses Dietz systems explicitly:

- `alkene_bridge` marks the `C#5 <-> C#6` two-electron alkene
- `phenyl_pi_ring` marks the six-edge aromatic ring over `C#10-C#11-C#12-C#14-C#15-C#16`
- `smilesStereochemistry` preserves the five atom-centered flags at centers `#2`, `#3`, `#7`, `#8`, and `#18`

That is the key comparison to the image. SMILES is still a useful boundary notation, but MolADT stores the polycycle, its delocalization, and its parsed stereochemistry flags directly instead of making string syntax the core representation. The conservative `parse-smiles` path keeps the Kekule-style double bonds from the boundary string explicit; the hand-built morphine example then groups the alkene and phenyl fragment into Dietz systems on purpose.

Use:

```bash
stack run moladtbayes -- pretty-example morphine
stack run moladtbayes -- parse-smiles "CN1CC[C@]23C4=C5C=CC(O)=C4O[C@H]2[C@@H](O)C=C[C@H]3[C@H]1C5"
```

The first command shows the explicit Dietz object. The second shows the boundary-format parse path based on the same figure.

## See Also

- [Examples](examples.md)
- [CLI and demo](cli-and-demo.md)
- [SMILES scope and validation](smiles-scope-and-validation.md)
