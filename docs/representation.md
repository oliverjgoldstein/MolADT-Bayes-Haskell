# MolADT Representation

MolADT is a molecule representation designed to stay explicit where SMILES is compressed.

## What Stays Explicit

MolADT keeps:

- atoms with coordinates
- localized sigma bonds
- Dietz-style bonding systems for delocalized and multicenter structure
- shell and orbital information on atoms

The core object is a molecule, not a serialization.

It is also not implemented as a hypergraph. The core adjacency is a set of ordinary undirected two-atom `Edge` values, and each bonding system is a separate object that refers back to a set of those edges. If you want graph language, this is closer to a layered or multiplex edge-annotated graph than to atom-level hyperedges.

## Why This Matters

SMILES is useful at the boundary, but it is still a renderer-oriented string syntax.

- ring closures are written indirectly through digits
- delocalization is expressed through shorthand conventions
- geometry is not the center of the representation
- richer bonding has to be approximated or pushed somewhere else

MolADT keeps the chemistry object first and treats SMILES as one boundary format among several.

## Concrete Examples

Diborane and ferrocene show the non-classical side of the story: the built-in examples keep multicenter bridges and metal-centered pools explicit even though the current classical SMILES renderer does not support them.

Standard boundary notation already compresses both:

```text
[BH2]1[H][BH2][H]1
[CH-]1C=CC=C1.[CH-]1C=CC=C1.[Fe+2]
```

Those are useful SMILES strings, but they flatten the diborane bridges and split ferrocene into ionic fragments instead of the explicit multicenter pools used in MolADT.

## Ferrocene in Code

The built-in ferrocene object is intentionally almost identical in Haskell and Python. Same atom ids, same sigma framework, same three Dietz systems.

The snippets below use the same direct-edge style as the built-in examples. In Python, `Edge(...)` canonicalizes the undirected pair for you; in Haskell, the examples use a small local helper before calling `Edge`. The important structural point is the same in both repos: the Cp `C-C` edges and Fe-Cp edges are reused across multiple Dietz systems, but they are not duplicated into a fake parallel-edge multigraph.

Haskell:

```haskell
canonicalEdge left right
  | left <= right = Edge left right
  | otherwise = Edge right left

edgeSetFromPairs = S.fromList . map (uncurry canonicalEdge)

fe      = AtomId 1
ring1C  = AtomId <$> [2..6]
ring2C  = AtomId <$> [7..11]
ring1H  = AtomId <$> [12..16]
ring2H  = AtomId <$> [17..21]

ring1CCPairs = ringPairs ring1C
ring2CCPairs = ringPairs ring2C
ring1CHPairs = zip ring1C ring1H
ring2CHPairs = zip ring2C ring2H
feToRing1    = [(fe, c) | c <- ring1C]
feToRing2    = [(fe, c) | c <- ring2C]

ferrocenePretty = Molecule
  { localBonds = edgeSetFromPairs (ring1CCPairs ++ ring2CCPairs ++ ring1CHPairs ++ ring2CHPairs)
  , systems =
      [ (SystemId 1, mkBondingSystem (NonNegative 6) (edgeSetFromPairs (feToRing1 ++ ring1CCPairs)) (Just "cp1_pi"))
      , (SystemId 2, mkBondingSystem (NonNegative 6) (edgeSetFromPairs (feToRing2 ++ ring2CCPairs)) (Just "cp2_pi"))
      , (SystemId 3, mkBondingSystem (NonNegative 6) (edgeSetFromPairs (feToRing1 ++ feToRing2)) (Just "fe_backdonation"))
      ]
  }
```

Expanded Haskell with explicit edge literals:

```haskell
ferrocenePretty = Molecule
  { localBonds =
      S.fromList
        [ Edge (AtomId 2) (AtomId 3)
        , Edge (AtomId 3) (AtomId 4)
        , Edge (AtomId 4) (AtomId 5)
        , Edge (AtomId 5) (AtomId 6)
        , Edge (AtomId 2) (AtomId 6)
        , Edge (AtomId 7) (AtomId 8)
        , Edge (AtomId 8) (AtomId 9)
        , Edge (AtomId 9) (AtomId 10)
        , Edge (AtomId 10) (AtomId 11)
        , Edge (AtomId 7) (AtomId 11)
        , Edge (AtomId 2) (AtomId 12)
        , Edge (AtomId 3) (AtomId 13)
        , Edge (AtomId 4) (AtomId 14)
        , Edge (AtomId 5) (AtomId 15)
        , Edge (AtomId 6) (AtomId 16)
        , Edge (AtomId 7) (AtomId 17)
        , Edge (AtomId 8) (AtomId 18)
        , Edge (AtomId 9) (AtomId 19)
        , Edge (AtomId 10) (AtomId 20)
        , Edge (AtomId 11) (AtomId 21)
        ]
  , systems =
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
              , Edge (AtomId 3) (AtomId 4)
              , Edge (AtomId 4) (AtomId 5)
              , Edge (AtomId 5) (AtomId 6)
              , Edge (AtomId 2) (AtomId 6)
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
              , Edge (AtomId 8) (AtomId 9)
              , Edge (AtomId 9) (AtomId 10)
              , Edge (AtomId 10) (AtomId 11)
              , Edge (AtomId 7) (AtomId 11)
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
  }
```

Python:

```python
def _edge_set(atom_pairs: tuple[tuple[AtomId, AtomId], ...]) -> frozenset[Edge]:
    return frozenset(Edge(atom_a, atom_b) for atom_a, atom_b in atom_pairs)


fe = AtomId(1)
ring1_c = tuple(AtomId(index) for index in range(2, 7))
ring2_c = tuple(AtomId(index) for index in range(7, 12))
ring1_h = tuple(AtomId(index) for index in range(12, 17))
ring2_h = tuple(AtomId(index) for index in range(17, 22))

ring1_cc = _ring_pairs(ring1_c)
ring2_cc = _ring_pairs(ring2_c)
ring1_ch = tuple(zip(ring1_c, ring1_h))
ring2_ch = tuple(zip(ring2_c, ring2_h))
fe_to_ring1 = tuple((fe, atom_id) for atom_id in ring1_c)
fe_to_ring2 = tuple((fe, atom_id) for atom_id in ring2_c)

ferrocene_pretty = Molecule(
    local_bonds=_edge_set(ring1_cc + ring2_cc + ring1_ch + ring2_ch),
    systems=(
        (SystemId(1), mk_bonding_system(NonNegative(6), _edge_set(fe_to_ring1 + ring1_cc), "cp1_pi")),
        (SystemId(2), mk_bonding_system(NonNegative(6), _edge_set(fe_to_ring2 + ring2_cc), "cp2_pi")),
        (SystemId(3), mk_bonding_system(NonNegative(6), _edge_set(fe_to_ring1 + fe_to_ring2), "fe_backdonation")),
    ),
)
```

Expanded Python with explicit edge literals:

```python
ferrocene_pretty = Molecule(
    local_bonds=frozenset(
        {
            Edge(AtomId(2), AtomId(3)),
            Edge(AtomId(3), AtomId(4)),
            Edge(AtomId(4), AtomId(5)),
            Edge(AtomId(5), AtomId(6)),
            Edge(AtomId(2), AtomId(6)),
            Edge(AtomId(7), AtomId(8)),
            Edge(AtomId(8), AtomId(9)),
            Edge(AtomId(9), AtomId(10)),
            Edge(AtomId(10), AtomId(11)),
            Edge(AtomId(7), AtomId(11)),
            Edge(AtomId(2), AtomId(12)),
            Edge(AtomId(3), AtomId(13)),
            Edge(AtomId(4), AtomId(14)),
            Edge(AtomId(5), AtomId(15)),
            Edge(AtomId(6), AtomId(16)),
            Edge(AtomId(7), AtomId(17)),
            Edge(AtomId(8), AtomId(18)),
            Edge(AtomId(9), AtomId(19)),
            Edge(AtomId(10), AtomId(20)),
            Edge(AtomId(11), AtomId(21)),
        }
    ),
    systems=(
        (
            SystemId(1),
            mk_bonding_system(
                NonNegative(6),
                frozenset(
                    {
                        Edge(AtomId(1), AtomId(2)),
                        Edge(AtomId(1), AtomId(3)),
                        Edge(AtomId(1), AtomId(4)),
                        Edge(AtomId(1), AtomId(5)),
                        Edge(AtomId(1), AtomId(6)),
                        Edge(AtomId(2), AtomId(3)),
                        Edge(AtomId(3), AtomId(4)),
                        Edge(AtomId(4), AtomId(5)),
                        Edge(AtomId(5), AtomId(6)),
                        Edge(AtomId(2), AtomId(6)),
                    }
                ),
                "cp1_pi",
            ),
        ),
        (
            SystemId(2),
            mk_bonding_system(
                NonNegative(6),
                frozenset(
                    {
                        Edge(AtomId(1), AtomId(7)),
                        Edge(AtomId(1), AtomId(8)),
                        Edge(AtomId(1), AtomId(9)),
                        Edge(AtomId(1), AtomId(10)),
                        Edge(AtomId(1), AtomId(11)),
                        Edge(AtomId(7), AtomId(8)),
                        Edge(AtomId(8), AtomId(9)),
                        Edge(AtomId(9), AtomId(10)),
                        Edge(AtomId(10), AtomId(11)),
                        Edge(AtomId(7), AtomId(11)),
                    }
                ),
                "cp2_pi",
            ),
        ),
        (
            SystemId(3),
            mk_bonding_system(
                NonNegative(6),
                frozenset(
                    {
                        Edge(AtomId(1), AtomId(2)),
                        Edge(AtomId(1), AtomId(3)),
                        Edge(AtomId(1), AtomId(4)),
                        Edge(AtomId(1), AtomId(5)),
                        Edge(AtomId(1), AtomId(6)),
                        Edge(AtomId(1), AtomId(7)),
                        Edge(AtomId(1), AtomId(8)),
                        Edge(AtomId(1), AtomId(9)),
                        Edge(AtomId(1), AtomId(10)),
                        Edge(AtomId(1), AtomId(11)),
                    }
                ),
                "fe_backdonation",
            ),
        ),
    ),
)
```

The close alignment is deliberate:

- atom `#1` is `Fe` in both repos
- atoms `#2..#6` and `#7..#11` are the two Cp rings in both repos
- `localBonds` or `local_bonds` contains only the localized `C-C` and `C-H` sigma framework
- the same three six-electron Dietz systems appear in both repos: `cp1_pi`, `cp2_pi`, and `fe_backdonation`
- the direct-edge examples keep canonical undirected edges explicitly; in Haskell that means writing the smaller atom id first whenever `Edge` is constructed directly
- the same undirected edge can appear in `localBonds` and again inside one or more bonding systems; that edge reuse is the intended Dietz structure, and it is not the same thing as duplicating edges into a fake multigraph

Morphine shows the classical fused-ring side more clearly.

The standard stereochemical boundary string is:

```text
CN1CC[C@]23C4=C5C=CC(O)=C4O[C@H]2[C@@H](O)C=C[C@H]3[C@H]1C5
```

That string is faithful for the classical graph, but it still compresses the fused skeleton into ring digits, localized double-bond syntax, and atom-centered `@`/`@@` flags.

In the explicit built-in morphine example at [`src/ExampleMolecules/Morphine.hs`](../src/ExampleMolecules/Morphine.hs), the five classical ring-closure edges from the standard sketch are just ordinary entries in `localBonds`:

- `O#1 ↔ C#11`
- `C#2 ↔ C#8`
- `C#7 ↔ C#18`
- `C#9 ↔ C#21`
- `C#10 ↔ C#16`

The example then uses Dietz systems explicitly:

- `alkene_bridge` marks the `C#5 <-> C#6` two-electron alkene
- `phenyl_pi_ring` marks the six-edge aromatic ring over `C#10-C#11-C#12-C#14-C#15-C#16`
- `smilesStereochemistry` preserves the five atom-centered flags at centers `#2`, `#3`, `#7`, `#8`, and `#18`

That is the key comparison to the image. SMILES is still a useful boundary notation, but MolADT stores the polycycle, its delocalization, and its parsed stereochemistry flags directly instead of making string syntax the core representation. The conservative `parse-smiles` path keeps the Kekule-style double bonds from the boundary string explicit; the hand-built morphine example then groups the alkene and phenyl fragment into Dietz systems on purpose.

Use:

```bash
stack run moladtbayes -- pretty-example morphine
stack run moladtbayes -- parse-smiles "CN1CC[C@]23C4=C5C=CC(O)=C4O[C@H]2[C@@H](O)C=C[C@H]3[C@H]1C5"
```

The first command shows the explicit Dietz object. The second shows the boundary-format parse path based on the same figure.

## See Also

- [Examples](examples.md)
- [CLI and demo](cli-and-demo.md)
- [SMILES scope and validation](smiles-scope-and-validation.md)
