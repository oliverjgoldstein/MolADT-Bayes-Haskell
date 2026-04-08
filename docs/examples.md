# Example Molecules

This repo mixes file-backed SDF examples with built-in Haskell modules. Benzene and water exist as local SDF files. Ferrocene, diborane, and morphine exist as built-in MolADT objects under `src/ExampleMolecules/`.

## At a Glance

| Example | Where it lives | Easiest inspection | What it demonstrates | Backing |
| --- | --- | --- | --- | --- |
| Benzene | [`molecules/benzene.sdf`](../molecules/benzene.sdf), [`src/ExampleMolecules/Benzene.hs`](../src/ExampleMolecules/Benzene.hs), [`src/ExampleMolecules/BenzenePretty.hs`](../src/ExampleMolecules/BenzenePretty.hs) | `stack run moladtbayes -- parse molecules/benzene.sdf` | Classical aromatic ring with one `pi_ring` system | Both file-backed and built-in |
| Water | [`molecules/water.sdf`](../molecules/water.sdf), [`src/SampleMolecules.hs`](../src/SampleMolecules.hs) | `stack run moladtbayes -- parse molecules/water.sdf` | Small classical molecule used in round-trip tests | Both file-backed and built-in |
| Morphine | [`src/ExampleMolecules/Morphine.hs`](../src/ExampleMolecules/Morphine.hs) | `stack run moladtbayes -- pretty-example morphine` | Explicit Dietz version of the classic morphine sketch, with the standard SMILES stereochemistry flags preserved on the object | Built-in object |
| Ferrocene | [`src/ExampleMolecules/Ferrocene.hs`](../src/ExampleMolecules/Ferrocene.hs) | `stack run moladtbayes -- pretty-example ferrocene` | Non-classical Fe-centered system with cyclopentadienyl pools and back-donation-style pool | Built-in object |
| Diborane | [`src/ExampleMolecules/Diborane.hs`](../src/ExampleMolecules/Diborane.hs) | `stack run moladtbayes -- pretty-example diborane` | Two explicit `3c-2e` bridges | Built-in object |

## Benzene

- File-backed source: [`molecules/benzene.sdf`](../molecules/benzene.sdf)
- Built-in sources: [`src/ExampleMolecules/Benzene.hs`](../src/ExampleMolecules/Benzene.hs) and [`src/ExampleMolecules/BenzenePretty.hs`](../src/ExampleMolecules/BenzenePretty.hs)

Use:

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
stack run moladtbayes -- to-smiles molecules/benzene.sdf
```

Benzene is the main classical example for the SDF parser, validator, and conservative SMILES round-trip boundary.

## Water

- File-backed source: [`molecules/water.sdf`](../molecules/water.sdf)
- Built-in source: [`src/SampleMolecules.hs`](../src/SampleMolecules.hs)

Use:

```bash
stack run moladtbayes -- parse molecules/water.sdf
```

Water is the smallest practical file-backed example in the repo and renders cleanly inside the conservative SMILES subset.

## Morphine

- Built-in source: [`src/ExampleMolecules/Morphine.hs`](../src/ExampleMolecules/Morphine.hs)

Use:

```bash
stack run moladtbayes -- pretty-example morphine
stack run moladtbayes -- parse-smiles "CN1CC[C@]23C4=C5C=CC(O)=C4O[C@H]2[C@@H](O)C=C[C@H]3[C@H]1C5"
```

Morphine is the cleanest built-in comparison point for the classic ring-closure image. The standard boundary SMILES carries ring digits, a localized double-bond pattern, and five atom-centered stereochemistry flags, while the built-in MolADT object stores those five edges directly in `localBonds`, marks the alkene plus phenyl delocalization as explicit Dietz systems, and preserves the stereochemistry flags in `smilesStereochemistry`. The conservative `parse-smiles` path keeps the localized double bonds explicit; the built-in morphine object then groups the alkene and phenyl fragment into Dietz systems on purpose.

## Side-by-Side SMILES vs MolADT

| Example | SMILES Side | MolADT Side |
| --- | --- | --- |
| Diborane | `[BH2]1[H][BH2][H]1` is standard, but it does not say "two explicit 3c-2e bridges". | `pretty-example diborane` shows two explicit `3c-2e` bridge systems over the bridging hydrogens. |
| Ferrocene | `[CH-]1C=CC=C1.[CH-]1C=CC=C1.[Fe+2]` is standard, but it splits the sandwich into ionic fragments. | `pretty-example ferrocene` shows the Fe-centered object with two Cp `pi` systems and one `fe_backdonation` pool. |
| Morphine | `CN1CC[C@]23C4=C5C=CC(O)=C4O[C@H]2[C@@H](O)C=C[C@H]3[C@H]1C5` | `pretty-example morphine` shows the same fused graph as direct `localBonds`, explicit `alkene_bridge` and `phenyl_pi_ring` systems, and preserved atom-centered stereochemistry flags. |

## Ferrocene and Diborane

These built-in examples are now inspectable through the main CLI as well:

```bash
stack run moladtbayes -- pretty-example ferrocene
stack run moladtbayes -- pretty-example diborane
```

- Ferrocene source: [`src/ExampleMolecules/Ferrocene.hs`](../src/ExampleMolecules/Ferrocene.hs)
- Diborane source: [`src/ExampleMolecules/Diborane.hs`](../src/ExampleMolecules/Diborane.hs)

These examples are important because they remain representable in the MolADT core even though they sit outside the supported classical SMILES renderer subset.

## `examples/ParseMolecules.hs`

[`examples/ParseMolecules.hs`](../examples/ParseMolecules.hs) is a small standalone example program that parses and validates the local benzene and water SDF files before pretty-printing them. It is already wired up as a runnable executable:

```bash
stack exec parse-molecules
```

Use it when you want the same benzene/water parse-and-validate flow without going through the main `moladtbayes` CLI dispatcher.
