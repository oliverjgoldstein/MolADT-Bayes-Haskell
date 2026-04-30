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

Add `--viewer-output <path>` to any built-in example when you want an HTML
viewer for the same typed molecule.

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
diboranePretty :: Molecule
diboranePretty = Molecule
  { atoms =
      M.fromList
        [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes B, coordinate = Coordinate (mkAngstrom (-0.885)) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells B, formalCharge = 0 })
        , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes B, coordinate = Coordinate (mkAngstrom 0.885) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells B, formalCharge = 0 })
        , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.9928), shells = elementShells H, formalCharge = 0 })
        , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom (-0.9928)), shells = elementShells H, formalCharge = 0 })
        , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.885)) (mkAngstrom 1.19) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
        , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.885)) (mkAngstrom (-1.19)) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
        , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.885) (mkAngstrom 1.19) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
        , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.885) (mkAngstrom (-1.19)) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
        ]
  , localBonds =
      S.fromList
        [ Edge (AtomId 1) (AtomId 2)
        , Edge (AtomId 1) (AtomId 5)
        , Edge (AtomId 1) (AtomId 6)
        , Edge (AtomId 2) (AtomId 7)
        , Edge (AtomId 2) (AtomId 8)
        ]
  , systems =
      [ (SystemId 1, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 3), Edge (AtomId 2) (AtomId 3)]) (Just "bridge_h3_3c2e"))
      , (SystemId 2, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 4), Edge (AtomId 2) (AtomId 4)]) (Just "bridge_h4_3c2e"))
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }
```

The checked examples use this canonical normal form: atoms sorted by `AtomId`,
edges written directly as normalized `Edge (AtomId a) (AtomId b)` values, and
systems sorted by `SystemId`. They do not hide atoms, sigma edges, or
bonding-system edges behind ranges, zips, helpers, or generated tables. That is
the kind of structure a Bayesian proposal kernel can edit directly.

Viewer version:

```bash
stack run moladtbayes -- pretty-example diborane --viewer-output results/viewer/diborane.viewer.html
stack run moladtbayes -- pretty-example ferrocene --viewer-output results/viewer/ferrocene.viewer.html
```

## Standalone Example

```bash
stack exec parse-molecules
```

This runs [`examples/ParseMolecules.hs`](../examples/ParseMolecules.hs), which
parses and validates the local benzene and water SDF files.

Next: [Representation](representation.md), [CLI and demo](cli-and-demo.md).
