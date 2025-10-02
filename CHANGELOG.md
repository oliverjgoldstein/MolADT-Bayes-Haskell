# Changelog

## [Unreleased]
### Changed

- Expanded logP model to incorporate hetero atom and hydrogen bonding features for improved MH sampling.


## [0.2.0] - 2025-08-24
### Added
- Pretty printers for weights and sampled molecules.
- Expanded documentation covering program functionality, build instructions, and LazyPPL disclaimer.
- Stack and Hpack configuration with source reorganized under `app/` and `src/`.

### Changed
- Upgraded compiler to GHC 9.6 and aligned Stack resolver.
- Regenerated project metadata including the `cabal` file and package manifest.

### Fixed
- Ensured `Molecule.hs` ends with a newline.

### Removed
- Deprecated BSD license in favor of AGPL-only licensing.

## [0.1.0] - 2023-10-05
### Added
- Initial release of the project.
- Basic Molecular ADT.
- Algebraic Molecular expression parser.
- Command-line interface for user interaction.
- Basic Probabilistic Inference with LazyPPL

### Fixed
- N/A

### Changed
- N/A

### Removed
- N/A
