# SMILES Scope and Validation

The Haskell SMILES layer matches the same conservative boundary used in the Python repo. The goal is a stable classical subset, not an over-extended encoding of every MolADT structure.

## Supported

- atoms and bracket atoms
- explicit bracket hydrogens and formal charges
- implicit terminal hydrogens on supported bare atoms such as `C`, `N`, `O`, halogens, and aromatic lowercase atoms
- atom-centered `@` and `@@` stereochemistry on bracket atoms
- directional `/` and `\` bond annotations
- branches
- ring digits `1-9`
- single, double, and triple bonds
- graph-based six-membered `pi_ring` recovery from aromatic lowercase input
- benzene-style aromatic input such as `c1ccccc1`
- fused classical ring cases such as the stereochemical morphine boundary string, with ring closures, localized double bonds, and atom-centered stereochemistry preserved conservatively

## Not Supported

- non-classical multicenter systems such as diborane and ferrocene
- arbitrary delocalized systems outside localized double/triple bonds and simple six-edge `pi_ring` cases
- components that need more than 9 ring closures

Those molecules still remain representable in the MolADT core. The restriction is on the current SMILES parser and renderer, not on the underlying ADT.

## What Gets Validated

The user-facing CLI validates structures before rendering or benchmarking:

- `parse` loads an SDF file, validates the molecule, then pretty-prints it.
- `parse-smiles` parses the conservative SMILES subset, validates the result, then pretty-prints it.
- `to-smiles` validates the molecule before trying to render it.

Validation checks include:

- self-bonds and missing-atom references
- symmetric bond-map construction
- maximum valence bounds by element

## Rendering Boundary

Current renderer rejections come directly from [`src/Chem/IO/SMILES.hs`](../src/Chem/IO/SMILES.hs), for example:

- `SMILES rendering only supports localized double/triple bonds and six-edge pi rings`
- `pi_ring must be a simple six-membered cycle to render as SMILES`
- `SMILES rendering currently supports at most 9 ring closures per component`

That is why:

- `c1ccccc1` is supported input
- bare `C` and bare `O` become methane- and water-style MolADT objects with inferred terminal hydrogens
- the stereochemical morphine boundary string preserves its five atom-centered `@`/`@@` flags and keeps its localized double-bond pattern explicit
- an explicit Kekule string stays explicit and does not get silently promoted to a delocalized `pi_ring`
- parsed SMILES stereochemistry is stored on `smilesStereochemistry`
- the current renderer does not yet regenerate `@`, `@@`, `/`, or `\` from stored stereochemistry annotations
- benzene from `molecules/benzene.sdf` renders successfully
- ferrocene and diborane remain valid MolADT examples but are not `to-smiles` targets

## Benchmarking Boundary

The Haskell inference baseline does not parse arbitrary SMILES during aligned regression. It consumes the standardized Python exports directly. The conservative SMILES boundary still matters for the CLI and for round-trip parser tests.

## Related Files

- [`src/Chem/IO/SMILES.hs`](../src/Chem/IO/SMILES.hs)
- [`src/Chem/Validate.hs`](../src/Chem/Validate.hs)
- [`test/parser-roundtrip/Main.hs`](../test/parser-roundtrip/Main.hs)
- [`test/validation-properties/Main.hs`](../test/validation-properties/Main.hs)
