# Orbitals

Orbital information lives on each atom as Haskell ADTs.

That matters because MolADT is not only a graph of element labels. It can carry
the typed chemical structure that later descriptors or models may inspect.

## Shape In Haskell

```haskell
data So = So
data P = Px | Py | Pz
data D = Dxy | Dyz | Dxz | Dx2y2 | Dz2
data F = Fxxx | Fxxy | Fxxz | Fxyy | Fxyz | Fxzz | Fzzz

data PureOrbital
  = PureSo So
  | PureP  P
  | PureD  D
  | PureF  F

data Orbital subshellType = Orbital
  { orbitalType      :: subshellType
  , electronCount    :: Int
  , orientation      :: Maybe Coordinate
  , hybridComponents :: Maybe [(Double, PureOrbital)]
  }

newtype SubShell subshellType = SubShell
  { orbitals :: [Orbital subshellType] }

data Shell = Shell
  { principalQuantumNumber :: Int
  , sSubShell              :: Maybe (SubShell So)
  , pSubShell              :: Maybe (SubShell P)
  , dSubShell              :: Maybe (SubShell D)
  , fSubShell              :: Maybe (SubShell F)
  }

type Shells = [Shell]
```

An atom points to `Shells`. A shell points to typed subshells. A subshell points
to orbitals.

```text
Molecule -> Atom -> Shells -> Shell -> SubShell -> Orbital
```

## What An Orbital Stores

An orbital can store:

- orbital type
- electron count
- optional orientation
- optional hybrid components

Because `Orbital` is parameterized by the subshell type, Haskell can distinguish
`Orbital P` from `Orbital D` at the type level.

## Iodine Example

Iodine's full shell definition is in [`src/Orbital.hs`](../src/Orbital.hs). The
final valence shell is explicit `5s2 5p5` data:

```haskell
Shell
  { principalQuantumNumber = 5
  , sSubShell = Just (SubShell
      [ Orbital
          { orbitalType      = So
          , electronCount    = 2
          , orientation      = Nothing
          , hybridComponents = Nothing
          }
      ])
  , pSubShell = Just (SubShell
      [ Orbital
          { orbitalType      = Px
          , electronCount    = 2
          , orientation      = Just (angCoord 1 0 0)
          , hybridComponents = Nothing
          }
      , Orbital
          { orbitalType      = Py
          , electronCount    = 1
          , orientation      = Just (angCoord 0 1 0)
          , hybridComponents = Nothing
          }
      , Orbital
          { orbitalType      = Pz
          , electronCount    = 0
          , orientation      = Nothing
          , hybridComponents = Nothing
          }
      ])
  , dSubShell = Nothing
  , fSubShell = Nothing
  }
```

## Why Keep It

For many tasks, a graph is enough. For theoretical-chemistry-facing tasks, the
model may need a richer typed object.

Keeping shells and orbitals in the ADT means later code can ask structured
questions without bolting a separate object model onto the side.

## What It Does Not Claim

This is not a full quantum chemistry engine. It is a typed representation that
can carry orbital-shaped data when the task needs it.

Next: [ADT representation](data-model.md), [Representation](representation.md).
