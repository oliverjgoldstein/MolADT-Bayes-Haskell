# Example Molecules

The examples show why MolADT is useful as typed data.

## At A Glance

| Example | Run | What it shows |
| --- | --- | --- |
| Benzene | `stack run moladtbayes -- parse molecules/benzene.sdf` | classical ring plus `pi_ring` system |
| Water | `stack run moladtbayes -- parse molecules/water.sdf` | small validated SDF example |
| Morphine | `stack run moladtbayes -- pretty-example morphine` | fused topology and stereo annotations |
| Diborane | `stack run moladtbayes -- pretty-example diborane` | two explicit `3c-2e` bridge systems |
| Ferrocene | `stack run moladtbayes -- pretty-example ferrocene` | Cp pi systems and Fe-centred bonding pool |

## Files

- Benzene: [`molecules/benzene.sdf`](../molecules/benzene.sdf),
  [`src/ExampleMolecules/Benzene.hs`](../src/ExampleMolecules/Benzene.hs)
- Water: [`molecules/water.sdf`](../molecules/water.sdf),
  [`src/SampleMolecules.hs`](../src/SampleMolecules.hs)
- Morphine: [`src/ExampleMolecules/Morphine.hs`](../src/ExampleMolecules/Morphine.hs)
- Diborane: [`src/ExampleMolecules/Diborane.hs`](../src/ExampleMolecules/Diborane.hs)
- Ferrocene: [`src/ExampleMolecules/Ferrocene.hs`](../src/ExampleMolecules/Ferrocene.hs)

## Boundary Notation vs MolADT

SMILES can name many molecules compactly. MolADT keeps the internal structure
available to code.

| Molecule | SMILES side | MolADT side |
| --- | --- | --- |
| Diborane | bridge bonding is compressed | explicit `3c-2e` systems |
| Ferrocene | often split into ionic fragments | explicit sandwich-style bonding systems |
| Morphine | ring closures are digit bookkeeping | direct sigma edges plus stereo layer |

For example, diborane is represented with named bridge systems:

```haskell
systems =
  [ (SystemId 1, mkBondingSystem (NonNegative 2) bridgeOneEdges (Just "3c-2e_bridge"))
  , (SystemId 2, mkBondingSystem (NonNegative 2) bridgeTwoEdges (Just "3c-2e_bridge"))
  ]
```

That is the kind of structure a Bayesian proposal kernel can edit directly.

## Standalone Example

```bash
stack exec parse-molecules
```

This runs [`examples/ParseMolecules.hs`](../examples/ParseMolecules.hs), which
parses and validates the local benzene and water SDF files.

Next: [Representation](representation.md), [CLI and demo](cli-and-demo.md).
