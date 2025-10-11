This is a datatype for molecules, complete with orbitals, reaction dynamics and group theoretic properties. It corresponds to the article here: https://arxiv.org/abs/2501.13633

## Quick Start

1. **Build the project**

   ```bash
   stack build
   ```

   `package.yaml` is processed by `hpack` to generate `chemalgprog.cabal`.

2. **Explore the curated MolADT façade**

   The primary examples live under `examples/` and exercise the new façade
   modules:

   ```bash
   stack exec parse-molecules        # Parse + validate sample SDF files
   stack exec serialize-molecule     # Serialise methane using Binary
   stack exec chemalgprog            # Full logP regression demo
   ```

   Each executable imports from `MolADT.*`, so they double as references for
   building your own applications on top of the façade. The logP demo parses
   and validates benzene and water before inferring coefficients from
   `logp/DB1.sdf` and predicting the partition coefficients of molecules in the
   held-out dataset.

Sample SDF files for these experiments are provided in `molecules/` and `logp/`.

An example Haskell representation of a molecule is available in `src/Benzene.hs`, which defines the `benzene` structure programmatically.

## Array backend

The logP regression pipeline now relies on the [`massiv`](https://hackage.haskell.org/package/massiv) array library for parallel-friendly map and fold operations. No manual flags are required—running `stack build` will automatically pull in the Massiv dependency declared in `package.yaml`.

Author: Oliver Goldstein (oliverjgoldstein@gmail.com)

## License

Distributed under the terms of the MolRep Commercial / Source-Available License (Approval Required). See [LICENSE](LICENSE) for details.

## LazyPPL Disclaimer

The probabilistic programming components (`LazyPPL.hs` and `Distr.hs`) are taken from the [LazyPPL project](https://github.com/lazyppl-team/lazyppl) by Swaraj Dash, Younesse Kaddar, Hugo Paquet, and Sam Staton. These files were not written by us and are included here with permission.

## What the Program Does

The `chemalgprog` executable parses the sample benzene molecule (`molecules/benzene.sdf`) to showcase structural validation, then loads `molecules/water.sdf` as the test molecule for the regression. Coefficients are inferred from the training set `logp/DB1.sdf`, the logP of water is predicted from these coefficients, and predicted versus observed values for all molecules in `logp/DB2.sdf` are printed. The additional `serialize-molecule` example demonstrates persisting molecules via the façade API.

See [`docs/getting-started.md`](docs/getting-started.md) for a guided tour of
the façade, including details on how each example uses the curated modules.


