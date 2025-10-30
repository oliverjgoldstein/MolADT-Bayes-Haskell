This is a datatype for molecules, complete with orbitals, reaction dynamics and group theoretic properties. It corresponds to the article here: https://arxiv.org/abs/2501.13633

## Quick Start

1. **Build the project**

   ```bash
   stack build
   ```

   `package.yaml` is processed by `hpack` to generate `moladtbayes.cabal`.

2. **Run the demonstration program**

   ```bash
   stack exec moladtbayes
   ```

   This executable:

   - Parses and validates `molecules/benzene.sdf`, printing the structure as a sanity check.
   - Parses `molecules/water.sdf` and uses it as a test molecule.
   - Performs a Metropolis–Hastings regression on the molecules in `logp/DB1.sdf` to learn coefficients that predict the partition coefficient (logP).
   - Applies the learned model to predict the logP of water and then prints predicted and observed values for each molecule in `logp/DB2.sdf`.

3. **Parse molecules independently (optional)**

   ```bash
   stack exec parse-molecules
   ```

   The example pretty-prints the contents of `molecules/benzene.sdf` and `molecules/water.sdf` using the library parser.

Sample SDF files for these experiments are provided in `molecules/` and `logp/`.

An example Haskell representation of a molecule is available in `src/Benzene.hs`, which defines the `benzene` structure programmatically.

## Blockchain Instruction Toolkit

The `InstructionsForBlockchain/` tree extends the original probabilistic modelling code with a self-contained toolkit for describing chemputer-ready, on-chain synthesis programs. It is layered around four core pieces:

1. **Deterministic blueprint hashing.** `InstructionsForBlockchain.Hash` serialises arbitrary payloads and produces 64-bit FNV-1a digests so that molecules and reactions can be anchored immutably on a ledger.

2. **Molecule blueprints.** `InstructionsForBlockchain.MoleculeBlueprint` converts `Chem.Molecule` values into transportable descriptions, verifies neighbourhood consistency, and emits provenance tags (hash, atom count, charge distribution) required by an automated chemputer.

3. **Chemputer instruction monad.** `InstructionsForBlockchain.ChemputerProgram` defines a `ChemputerProgram` monad that sequences primitive operations (`registerBlueprint`, `dose`, `adjustTemperature`, `captureProduct`, etc.) while accumulating structured `Instruction` records ready for blockchain storage or auditing.

4. **Demonstration scripts.**
   - `InstructionsForBlockchain.Example` walks through a full hydrogen-combustion scenario, compiling 13 instructions and providing pretty-printers for humans and hashes for contracts.
   - `InstructionsForBlockchain.Minimal` trims this down to a minimal water synthesis demo. The helper `runMinimalDemo` renders the instruction log, and `Main` executes it automatically when you run `stack exec moladtbayes`.

### Running the demos

1. **Build the library** using `stack build` (or `cabal build`). This ensures the blockchain modules compile alongside the original regression pipeline.

2. **Run the executable demo**:

   ```bash
   stack exec moladtbayes
   ```

   After the existing regression diagnostics print, the program emits the minimal blockchain instruction script. You will see each numbered step with its operation, deterministic blueprint hash, and human-readable note.

3. **Explore the richer example in GHCi**:

   ```haskell
   stack repl
   > import InstructionsForBlockchain.Example
   > putStrLn (Data.Text.unpack prettyCombustionScript)
   ```

   This shows the extended combustion walk-through along with the provenance metadata that would be persisted on-chain.

## Array backend

The logP regression pipeline now relies on the [`massiv`](https://hackage.haskell.org/package/massiv) array library for parallel-friendly map and fold operations. No manual flags are required—running `stack build` will automatically pull in the Massiv dependency declared in `package.yaml`.

Author: Oliver Goldstein (oliverjgoldstein@gmail.com)

## License

Distributed under the terms of the MolRep Commercial / Source-Available License (Approval Required). See [LICENSE](LICENSE) for details.

## LazyPPL Disclaimer

The probabilistic programming components (`LazyPPL.hs` and `Distr.hs`) are taken from the [LazyPPL project](https://github.com/lazyppl-team/lazyppl) by Swaraj Dash, Younesse Kaddar, Hugo Paquet, and Sam Staton. These files were not written by us and are included here with permission.

## What the Program Does

The `moladtbayes` executable parses the sample benzene molecule (`molecules/benzene.sdf`) to showcase structural validation, then loads `molecules/water.sdf` as the test molecule for the regression. Coefficients are inferred from the training set `logp/DB1.sdf`, the logP of water is predicted from these coefficients, and predicted versus observed values for all molecules in `logp/DB2.sdf` are printed. The `parse-molecules` example demonstrates parsing and validating multiple SDF files.

