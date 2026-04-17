# MolADT Data Model

In Haskell, MolADT is already a direct algebraic data type. The core molecule value is just one record with explicit chemistry fields.

## Molecule

```haskell
data Molecule = Molecule
  { atoms :: Map AtomId Atom
  , localBonds :: Set Edge
  , systems :: [(SystemId, BondingSystem)]
  , smilesStereochemistry :: SmilesStereochemistry
  }
```

This is the ADT story in the simplest possible form: one product type whose fields are the molecule.

- `atoms`: the typed atom table
- `localBonds`: the explicit sigma-network edges
- `systems`: the non-local Dietz bonding systems
- `smilesStereochemistry`: boundary stereochemistry annotations

## Atom And Orbitals

Each atom carries coordinate, charge, and shell structure directly.

```haskell
data Atom = Atom
  { atomID :: AtomId
  , attributes :: ElementAttributes
  , coordinate :: Coordinate
  , shells :: Shells
  , formalCharge :: Int
  }
```

The orbital side is also explicit:

```haskell
data Orbital subshellType = Orbital
  { orbitalType :: subshellType
  , electronCount :: Int
  , orientation :: Maybe Coordinate
  , hybridComponents :: Maybe [(Double, PureOrbital)]
  }

newtype SubShell subshellType = SubShell
  { orbitals :: [Orbital subshellType]
  }

data Shell = Shell
  { principalQuantumNumber :: Int
  , sSubShell :: Maybe (SubShell So)
  , pSubShell :: Maybe (SubShell P)
  , dSubShell :: Maybe (SubShell D)
  , fSubShell :: Maybe (SubShell F)
  }

type Shells = [Shell]
```

So the full shape is: `Molecule` contains `Atom`, and each `Atom` contains `Shells`.

## Relation To Python

The Python repo mirrors this ADT closely:

```python
@dataclass(frozen=True, slots=True)
class Molecule:
    atoms: Mapping[AtomId, Atom]
    local_bonds: frozenset[Edge]
    systems: tuple[tuple[SystemId, BondingSystem], ...]
    smiles_stereochemistry: SmilesStereochemistry = field(default_factory=SmilesStereochemistry)
```

That Python `Molecule` is meant to feel like this Haskell record, not like a large object-oriented API.

Python also has a `MutableMolecule` helper for local edits before calling `freeze()`. There is no separate mutable type on the Haskell side; the normal approach is to build a new immutable `Molecule` value.

If you want the shortest summary, think of MolADT as:

`Molecule = atoms + local bonds + bonding systems + stereo annotations`

with orbital structure stored directly on each atom.
