# Orbitals

Orbital information lives on each atom.

That matters because MolADT is not only a graph of element labels. It can carry
the typed chemical structure that later descriptors or models may inspect.

## Shape

```haskell
data Atom = Atom
  { shells :: Shells
  }

type Shells = [Shell]
```

An atom points to shells. A shell points to subshells. A subshell points to
orbitals.

```text
Molecule -> Atom -> Shells -> Shell -> SubShell -> Orbital
```

## What An Orbital Stores

An orbital can store:

- orbital type
- electron count
- optional orientation
- optional hybrid components

## Why Keep It

For many tasks, a graph is enough. For theoretical-chemistry-facing tasks, the
model may need a richer typed object.

Keeping shells and orbitals in the ADT means later code can ask structured
questions without bolting a separate object model onto the side.

## What It Does Not Claim

This is not a full quantum chemistry engine. It is a typed representation that
can carry orbital-shaped data when the task needs it.

Next: [ADT representation](data-model.md), [Representation](representation.md).
