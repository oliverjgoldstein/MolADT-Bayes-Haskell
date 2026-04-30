# MolADT ADT Representation

MolADT is a molecule as typed Haskell data.

```text
Molecule = atoms + sigma edges + bonding systems + stereochemistry
```

## Core Shape

```haskell
data Molecule = Molecule
  { atoms :: Map AtomId Atom
  , localBonds :: Set Edge
  , systems :: [(SystemId, BondingSystem)]
  , smilesStereochemistry :: SmilesStereochemistry
  }
```

That gives one explicit object with four layers:

- `atoms`: atom table
- `localBonds`: localized sigma network
- `systems`: Dietz bonding systems for delocalized or multicentre chemistry
- `smilesStereochemistry`: stereo annotations from boundary notation

## Minimal Example

This is the shape of water as a typed molecule:

```haskell
water :: Molecule
water = Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.96) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.32)) (mkAngstrom 0.9) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 3)
      ]
  , systems = []
  , smilesStereochemistry = emptySmilesStereochemistry
  }
```

The important part is not the specific molecule. It is the separation between
atoms, local bonds, bonding systems, and stereo.

## Bonding Systems

```haskell
data Edge = Edge AtomId AtomId

data BondingSystem = BondingSystem
  { sharedElectrons :: NonNegative
  , memberAtoms     :: Set AtomId
  , memberEdges     :: Set Edge
  , tag             :: Maybe String
  }
```

`localBonds` and `systems` are separate layers. A sigma edge can exist in the
ordinary graph and also belong to a delocalized system.

That is how MolADT can represent things like:

- benzene `pi_ring`
- diborane `3c-2e` bridges
- ferrocene Cp/metal systems

Example shape for one benzene-style pi system:

```haskell
piRing :: BondingSystem
piRing =
  mkBondingSystem
    (NonNegative 6)
    (S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 6)
      , Edge (AtomId 2) (AtomId 3)
      , Edge (AtomId 3) (AtomId 4)
      , Edge (AtomId 4) (AtomId 5)
      , Edge (AtomId 5) (AtomId 6)
      ])
    (Just "pi_ring")
```

Checked molecules use this direct canonical form: literal atoms, normalized
`Edge` constructors, and sorted bonding systems.

## Atoms

```haskell
data Atom = Atom
  { atomID       :: AtomId
  , attributes   :: ElementAttributes
  , coordinate   :: Coordinate
  , shells       :: Shells
  , formalCharge :: Int
  }
```

Each atom carries identity, element data, coordinates, shell structure, and
formal charge.

## Stereo

SMILES stereochemistry is kept in its own layer. It is not hidden inside an
edge or atom string.

This keeps the core molecule inspectable while still preserving boundary
stereo information.

## Python Match

The Python repo mirrors the same shape with frozen dataclasses. That is why the
shared JSON boundary can move molecules between Haskell and Python without
changing the chemistry object.

Next: [Representation](representation.md), [Python interop](python-interop.md).
