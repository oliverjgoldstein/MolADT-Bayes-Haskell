# Orbitals

This page explains the orbital layer in the Haskell MolADT and why its types fit theoretical chemistry rather than just acting as extra metadata.

## What Is In The ADT

In Haskell, orbitals sit directly on atoms:

`Molecule -> Atom -> Shells -> Shell -> SubShell -> Orbital`

The core declarations live in [`src/Orbital.hs`](../src/Orbital.hs):

- `So`, `P`, `D`, and `F` describe the pure orbital families
- `Orbital subshellType` stores:
  - `orbitalType`
  - `electronCount`
  - optional `orientation`
  - optional `hybridComponents`
- `SubShell subshellType` stores orbitals from one angular-momentum family
- `Shell` stores one principal quantum number plus optional `s`, `p`, `d`, and `f` subshells

Atoms then carry `shells`, so the orbital layer is part of the molecule value itself.

## Why The Types Fit Theoretical Chemistry

The type structure follows the chemistry closely.

- `Shell` separates data by principal quantum number `n`.
- `SubShell P` contains only `p` orbitals, `SubShell D` only `d` orbitals, and so on. That rules out category mistakes that are chemically meaningless.
- `electronCount` is explicit on each orbital, so occupancy is represented directly.
- `orientation` gives a place for directional orbital information.
- `hybridComponents` lets an orbital be described as a weighted combination of pure orbitals, which matches the shape of hybridization talk without requiring the whole ADT to become a full quantum-chemistry solver.

That is why the design fits theoretical chemistry: the types express shell structure, angular character, occupancy, and optional hybridization in the same shape that the theory talks about them.

## Why This Is Better Than A Reduced Graph

A graph-only molecular object is good at connectivity, but poor at local electronic structure.

The orbital layer keeps visible:

- shell filling
- directional `p`, `d`, and `f` content
- explicit hybrid decomposition when it matters

That makes the ADT better aligned with chemical reasoning than a representation that stops at atoms and edges.

## What This Does Not Claim

This is not a complete quantum-chemistry package.

It does not represent:

- a full basis-set calculation
- SCF or post-SCF state
- global molecular orbitals
- overlap, Fock, or Hamiltonian matrices
- full radial parameterization

So the right interpretation is: typed local orbital structure on atoms, not a complete wavefunction description.

## Why Keep It Anyway

For MolADT, the orbital layer is useful because it keeps more chemistry inside the ADT itself.

- It makes printed atoms more informative.
- It gives other code a typed place to inspect shell and orbital structure.
- It stays faithful to the Haskell style of explicit algebraic data with clear invariants.

That is the point of the design: richer than a graph-only molecule, but still simple enough to be a reusable typed core.
