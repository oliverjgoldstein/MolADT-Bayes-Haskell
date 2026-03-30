# Example Molecules

This repo mixes file-backed SDF examples with built-in Haskell modules. Benzene and water exist as local SDF files. Ferrocene and diborane exist as built-in MolADT objects under `src/ExampleMolecules/`.

## At a Glance

| Example | Where it lives | Easiest inspection | What it demonstrates | Backing |
| --- | --- | --- | --- | --- |
| Benzene | [`molecules/benzene.sdf`](../molecules/benzene.sdf), [`src/ExampleMolecules/Benzene.hs`](../src/ExampleMolecules/Benzene.hs), [`src/ExampleMolecules/BenzenePretty.hs`](../src/ExampleMolecules/BenzenePretty.hs) | `stack run moladtbayes -- parse molecules/benzene.sdf` | Classical aromatic ring with one `pi_ring` system | Both file-backed and built-in |
| Water | [`molecules/water.sdf`](../molecules/water.sdf), [`src/SampleMolecules.hs`](../src/SampleMolecules.hs) | `stack run moladtbayes -- parse molecules/water.sdf` | Small classical molecule used in round-trip tests | Both file-backed and built-in |
| Ferrocene | [`src/ExampleMolecules/Ferrocene.hs`](../src/ExampleMolecules/Ferrocene.hs) | `stack ghci` snippet below | Non-classical Fe-centered system with cyclopentadienyl pools and back-donation-style pool | Built-in object |
| Diborane | [`src/ExampleMolecules/Diborane.hs`](../src/ExampleMolecules/Diborane.hs) | `stack ghci` snippet below | Two explicit `3c-2e` bridges | Built-in object |

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

## Ferrocene and Diborane

There is no dedicated CLI subcommand for these built-in non-classical examples today. Use `stack ghci` with the real module names instead:

```bash
stack ghci
```

Then:

```haskell
:module +ExampleMolecules.Ferrocene ExampleMolecules.Diborane Chem.Molecule Chem.Validate
putStrLn (prettyPrintMolecule ferrocenePretty)
putStrLn (prettyPrintMolecule diboranePretty)
validateMolecule ferrocenePretty
validateMolecule diboranePretty
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
