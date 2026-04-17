# MolADT ADT Representation

In Haskell, MolADT is already a direct algebraic data type. The full representation is a small family of records and sums that make the molecule explicit instead of flattening it into a boundary string.

## Full Shape

At a high level, the nested shape is:

```text
Molecule
  = atoms :: Map AtomId Atom
  + localBonds :: Set Edge
  + systems :: [(SystemId, BondingSystem)]
  + smilesStereochemistry :: SmilesStereochemistry

Atom
  = atomID
  + attributes :: ElementAttributes
  + coordinate :: Coordinate
  + shells :: Shells
  + formalCharge

BondingSystem
  = sharedElectrons
  + memberAtoms
  + memberEdges
  + tag
```

So MolADT is not just a graph and not just a notation. It is:

- a typed atom table
- an explicit sigma-network
- a Dietz bonding-system layer for delocalized or multicenter chemistry
- a stereo annotation layer
- orbital shell structure carried directly on each atom

## Core Molecule Record

```haskell
data Molecule = Molecule
  { atoms :: Map AtomId Atom
  , localBonds :: Set Edge
  , systems :: [(SystemId, BondingSystem)]
  , smilesStereochemistry :: SmilesStereochemistry
  }
```

This is the ADT story in the simplest possible form: one product type whose fields are the molecule.

- `atoms` is the main atom table
- `localBonds` is the undirected sigma-network
- `systems` is the non-local Dietz layer
- `smilesStereochemistry` is the stereo layer from a SMILES-style boundary format

## Dietz Layer

The constitution-level primitives live in `Chem.Dietz`.

```haskell
newtype AtomId   = AtomId Integer
newtype SystemId = SystemId Int
newtype NonNegative = NonNegative { getNN :: Int }

data Edge = Edge AtomId AtomId

data BondingSystem = BondingSystem
  { sharedElectrons :: NonNegative
  , memberAtoms     :: Set AtomId
  , memberEdges     :: Set Edge
  , tag             :: Maybe String
  }
```

This is what makes MolADT more expressive than a plain graph.

- `Edge` is a canonical undirected pair
- `localBonds` stores the localized sigma framework
- `BondingSystem` adds one electron-sharing system over a set of edges
- `tag` is an optional label for a ring, bridge, or other named system

So `localBonds` and `systems` are different layers of the same molecule, not duplicates of each other.

## Atom Record

Each atom is also explicit:

```haskell
data ElementAttributes = ElementAttributes
  { symbol       :: AtomicSymbol
  , atomicNumber :: Int
  , atomicWeight :: Double
  }

data Atom = Atom
  { atomID       :: AtomId
  , attributes   :: ElementAttributes
  , coordinate   :: Coordinate
  , shells       :: Shells
  , formalCharge :: Int
  }
```

That means an atom carries:

- identity
- element information
- coordinates
- shell structure
- explicit formal charge

## Stereo Layer

The boundary stereo layer is explicit and separate from the bonding layer.

```haskell
data SmilesAtomStereo = SmilesAtomStereo
  { stereoCenter        :: AtomId
  , stereoClass         :: SmilesAtomStereoClass
  , stereoConfiguration :: Int
  , stereoToken         :: String
  }

data SmilesBondStereo = SmilesBondStereo
  { bondStereoStart     :: AtomId
  , bondStereoEnd       :: AtomId
  , bondStereoDirection :: SmilesBondStereoDirection
  }

data SmilesStereochemistry = SmilesStereochemistry
  { atomStereoAnnotations :: [SmilesAtomStereo]
  , bondStereoAnnotations :: [SmilesBondStereo]
  }
```

This matters structurally:

- stereochemistry is not hidden inside the edge set
- atom stereo and bond stereo are separate records
- the full `Molecule` still keeps them as one explicit field

## Orbitals And Shells

The orbital side is also part of the ADT.

```haskell
data Orbital subshellType = Orbital
  { orbitalType      :: subshellType
  , electronCount    :: Int
  , orientation      :: Maybe Coordinate
  , hybridComponents :: Maybe [(Double, PureOrbital)]
  }

newtype SubShell subshellType = SubShell
  { orbitals :: [Orbital subshellType]
  }

data Shell = Shell
  { principalQuantumNumber :: Int
  , sSubShell              :: Maybe (SubShell So)
  , pSubShell              :: Maybe (SubShell P)
  , dSubShell              :: Maybe (SubShell D)
  , fSubShell              :: Maybe (SubShell F)
  }

type Shells = [Shell]
```

So the structural path is:

`Molecule -> Atom -> Shells -> Shell -> SubShell -> Orbital`

That is why MolADT is better understood as a typed ADT tree than as a thin molecule string wrapper.

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

That Python `Molecule` is meant to feel like this Haskell record, not like a method-heavy object model.

Python also has a `MutableMolecule` helper for local edits before calling `freeze()`. There is no separate mutable type on the Haskell side; the normal approach is to build a new immutable `Molecule` value.

If you want the shortest summary, MolADT is:

`Molecule = atoms + sigma edges + bonding systems + stereo annotations`

with shell and orbital structure stored directly on each atom.
