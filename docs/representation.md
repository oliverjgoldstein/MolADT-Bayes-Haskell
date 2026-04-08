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

Morphine shows the classical fused-ring side more clearly.

The classic morphine figure breaks five ring closures, numbers them, and then emits this boundary string:

```text
O1C2C(O)C=C(C3C2(C4)C5c1c(O)ccc5CC3N(C)C4)
```

In that notation, the digits are backreferences:

- `1` reconnects `O#1` and `C#11`
- `2` reconnects `C#2` and `C#8`
- `3` reconnects `C#7` and `C#18`
- `4` reconnects `C#9` and `C#21`
- `5` reconnects `C#10` and `C#16`

In the explicit built-in morphine example at [`src/ExampleMolecules/Morphine.hs`](../src/ExampleMolecules/Morphine.hs), those are just ordinary entries in `localBonds`. The example then uses Dietz systems explicitly:

- `alkene_bridge` marks the `C#5 <-> C#6` two-electron alkene
- `phenyl_pi_ring` marks the six-edge aromatic ring over `C#10-C#11-C#12-C#14-C#15-C#16`

That is the key comparison to the image. The image is a recipe for turning a polycycle into SMILES text. MolADT stores the polycycle and its delocalization directly, without going through ring digits as an internal representation.

Use:

```bash
stack run moladtbayes -- pretty-example morphine
stack run moladtbayes -- parse-smiles "O1C2C(O)C=C(C3C2(C4)C5c1c(O)ccc5CC3N(C)C4)"
```

The first command shows the explicit Dietz object. The second shows the boundary-format parse path based on the same figure.

## See Also

- [Examples](examples.md)
- [CLI and demo](cli-and-demo.md)
- [SMILES scope and validation](smiles-scope-and-validation.md)
