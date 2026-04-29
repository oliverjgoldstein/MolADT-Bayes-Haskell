# MolADT Representation

MolADT keeps chemistry explicit.

SMILES is useful for exchange. A plain graph is useful for traversal. MolADT is
the typed object used inside the program.

## What Stays Explicit

- atoms
- coordinates
- formal charge
- shell and orbital data
- localized sigma bonds
- delocalized or multicentre bonding systems
- SMILES stereochemistry annotations

## Why This Matters

Bayesian tasks need to inspect and modify molecules repeatedly.

With MolADT, a proposal kernel can edit an atom, add a bond, change terminal
hydrogens, or add a Dietz system directly. It does not have to rewrite a
string and then hope the chemistry comes back the same.

That makes MolADT a useful explicit typed generative model for Bayesian
inference and inverse design.

## Not Just A Graph

The local bond network is an ordinary set of undirected `Edge` values.

The non-local chemistry is stored separately:

```text
localBonds = sigma framework
systems    = electron-sharing systems over atoms and edges
```

This is closer to a layered molecule object than to a single flattened graph.

## Examples

| Molecule | Boundary notation hides | MolADT keeps |
| --- | --- | --- |
| Benzene | aromatic shorthand | an explicit `pi_ring` system |
| Diborane | bridge bonding | two `3c-2e` systems |
| Ferrocene | sandwich bonding | Cp pi systems and Fe-centred bonding pool |
| Morphine | fused ring bookkeeping | direct sigma edges plus stereo annotations |

Run:

```bash
stack run moladtbayes -- pretty-example ferrocene
stack run moladtbayes -- pretty-example diborane
stack run moladtbayes -- pretty-example morphine
```

The ferrocene example uses one atom table, one local sigma network, and several
Dietz systems over the same molecule:

```haskell
ferrocenePretty = Molecule
  { atoms = ...
  , localBonds = edgeSetFromPairs (ring1CCPairs ++ ring2CCPairs ++ ringCHPairs)
  , systems =
      [ (SystemId 1, mkBondingSystem (NonNegative 6) cp1Edges (Just "cp1_pi"))
      , (SystemId 2, mkBondingSystem (NonNegative 6) cp2Edges (Just "cp2_pi"))
      , (SystemId 3, mkBondingSystem (NonNegative 6) feEdges  (Just "fe_backdonation"))
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }
```

The real source is
[`src/ExampleMolecules/Ferrocene.hs`](../src/ExampleMolecules/Ferrocene.hs).

## Where To Read Next

- [ADT representation](data-model.md)
- [Examples](examples.md)
- [Orbitals](orbitals.md)
- [Models and exported features](models.md)
