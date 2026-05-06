# MolADT Representation

MolADT keeps chemistry explicit as Haskell data.

SMILES and SDF are boundary formats. A plain graph is useful for traversal.
MolADT is the typed value used inside the program.

## Core Idea

```text
boundary notation -> parser -> Molecule ADT -> validation/model/viewer
```

Once parsed, the molecule is a record:

```haskell
data Molecule = Molecule
  { atoms :: Map AtomId Atom
  , localBonds :: Set Edge
  , systems :: [(SystemId, BondingSystem)]
  , smilesStereochemistry :: SmilesStereochemistry
  }
```

The fields stay separate because they mean different things.

| Field | Meaning |
| --- | --- |
| `atoms` | element data, coordinates, formal charge, optional shells, orbitals |
| `systems` | canonical Dietz electron-sharing systems over atoms and edges |
| `localBonds` | derived edge index for traversal and legacy callers |
| `smilesStereochemistry` | stereo annotations preserved from notation |

Every edge is represented by a bonding system. Conventional single, double, and
triple bonds are one-edge systems with `2`, `4`, and `6` shared electrons,
tagged `single`, `double`, and `triple`.

## Why This Matters

Bayesian tasks need to inspect and modify molecules repeatedly.

With MolADT, a proposal kernel can edit an atom, add a bond, change terminal
hydrogens, or add a Dietz system directly. It does not have to rewrite a string
and then hope the chemistry comes back the same.

That makes MolADT a useful explicit typed generative model for Bayesian
inference and inverse design:

- priors can be written over atoms, charges, edges, rings, and systems
- proposal moves can preserve typed invariants as they edit
- likelihood code sees the same explicit object as validation and serialization
- posterior samples can round-trip through the shared MolADT JSON boundary

## Not Just A Graph

The edge index is an ordinary set of undirected `Edge` values. The electron
sharing is stored in bonding systems:

```text
localBonds = derived edge index
systems    = canonical electron-sharing systems over atoms and edges
```

This is closer to a layered molecule object than to a single flattened graph.

Examples:

| Molecule | Boundary notation hides | MolADT keeps |
| --- | --- | --- |
| Benzene | aromatic shorthand | one-edge `single` systems plus an explicit `pi_ring` system |
| Diborane | bridge bonding | terminal `single` systems plus two `3c-2e` systems |
| Ferrocene | sandwich bonding | Cp/C-H edge systems plus Cp pi systems and Fe-centred bonding pool |
| Morphine | fused ring bookkeeping | every edge as a system plus stereo annotations |

## Explicit Haskell Examples

The built-in examples are plain Haskell values. They are intentionally expanded
so the ADT is visible in source.

```bash
stack run moladtbayes -- pretty-example ferrocene
stack run moladtbayes -- pretty-example diborane
stack run moladtbayes -- pretty-example morphine
```

The ferrocene source uses one atom table, an edge index, and explicit Dietz
systems. Legacy edge-index entries are normalized into one-edge `single`
systems; the named bonding systems are direct `S.fromList` values:

```haskell
systems =
  [ ( SystemId 1
    , mkBondingSystem
        (NonNegative 6)
        (S.fromList
          [ Edge (AtomId 1) (AtomId 2)
          , Edge (AtomId 1) (AtomId 3)
          , Edge (AtomId 1) (AtomId 4)
          , Edge (AtomId 1) (AtomId 5)
          , Edge (AtomId 1) (AtomId 6)
          , Edge (AtomId 2) (AtomId 3)
          , Edge (AtomId 2) (AtomId 6)
          , Edge (AtomId 3) (AtomId 4)
          , Edge (AtomId 4) (AtomId 5)
          , Edge (AtomId 5) (AtomId 6)
          ])
        (Just "cp1_pi")
    )
  , ( SystemId 2
    , mkBondingSystem
        (NonNegative 6)
        (S.fromList
          [ Edge (AtomId 1) (AtomId 7)
          , Edge (AtomId 1) (AtomId 8)
          , Edge (AtomId 1) (AtomId 9)
          , Edge (AtomId 1) (AtomId 10)
          , Edge (AtomId 1) (AtomId 11)
          , Edge (AtomId 7) (AtomId 8)
          , Edge (AtomId 7) (AtomId 11)
          , Edge (AtomId 8) (AtomId 9)
          , Edge (AtomId 9) (AtomId 10)
          , Edge (AtomId 10) (AtomId 11)
          ])
        (Just "cp2_pi")
    )
  , ( SystemId 3
    , mkBondingSystem
        (NonNegative 6)
        (S.fromList
          [ Edge (AtomId 1) (AtomId 2)
          , Edge (AtomId 1) (AtomId 3)
          , Edge (AtomId 1) (AtomId 4)
          , Edge (AtomId 1) (AtomId 5)
          , Edge (AtomId 1) (AtomId 6)
          , Edge (AtomId 1) (AtomId 7)
          , Edge (AtomId 1) (AtomId 8)
          , Edge (AtomId 1) (AtomId 9)
          , Edge (AtomId 1) (AtomId 10)
          , Edge (AtomId 1) (AtomId 11)
          ])
        (Just "fe_backdonation")
    )
  ]
```

The complete source is
[`src/ExampleMolecules/Ferrocene.hs`](../src/ExampleMolecules/Ferrocene.hs).

## Type Classes And Group Actions

Haskell gives the representation another useful tool: type classes can state
algebraic contracts separately from the molecule data.

The repo has a small `Group` type class in
[`src/Group.hs`](../src/Group.hs):

```haskell
class Group g where
  mul :: g -> g -> g
  inv :: g -> g
  e   :: g -> g
```

That pattern is useful for geometric deep learning and Bayesian models. A
rotation, translation, atom relabeling, or rigid transform can be the group
element. A molecule can then be the value acted on by that group.

The same module also exposes the action shape:

```haskell
class Group g => ActsOn g a where
  act :: g -> a -> a
```

For molecules, the laws are the important part:

```haskell
act (e g) molecule == molecule
act (mul g h) molecule == act g (act h molecule)
act (inv g) (act g molecule) == molecule
```

That is how the Haskell representation can express invariance and equivariance
clearly:

- scalar molecular properties should be invariant under rigid rotations
- vector or tensor properties should rotate equivariantly
- atom relabeling should not change chemistry
- proposal kernels can preserve group-action laws while editing molecules

Strictly, not every molecule is itself a group. More often, transformations are
group instances and `Molecule` is the acted-on value. If a molecule-like object
does have a lawful composition, Haskell can express that with a `Group`
instance too.

## Where To Read Next

- [ADT data model](data-model.md)
- [Examples](examples.md)
- [Orbitals](orbitals.md)
- [Models and exported features](models.md)
