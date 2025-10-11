# Getting Started with MolADT

The MolADT façade collects the project’s core functionality into a stable set
of modules that can be used from scripts, notebooks, or the included example
executables. This guide walks through the typical workflow: building the
project, parsing and validating molecules from SDF files, serialising
molecules, and running the logP regression demo.

## 1. Build the library

```bash
stack build
```

Building compiles both the library and the included executables. The build step
also runs `hpack` automatically, so edits to `package.yaml` propagate to the
Cabal file without manual intervention.

## 2. Parse and validate molecules

The `parse-molecules` example demonstrates the curated parsing and validation
API:

```bash
stack exec parse-molecules
```

The program calls `MolADT.Parse.readSDF` to decode the sample SDF files in
`molecules/`, checks the results with `MolADT.Validate.validateMolecule`, and
pretty-prints the structures using `MolADT.Molecule.prettyPrintMolecule`.

## 3. Serialise a molecule

The `serialize-molecule` executable shows how to persist molecules using the
Binary instances bundled with the library:

```bash
stack exec serialize-molecule
```

It writes the in-memory methane example from `MolADT.Samples.methane` to
`methane.bin` with `MolADT.Serialization.writeMoleculeToFile` and then reads it
back using `MolADT.Serialization.readMoleculeFromFile`, printing the recovered
structure.

## 4. Run the logP regression demo

The main demonstration executable, `chemalgprog`, now delegates to the
`examples/RunLogP.hs` script. It exercises the probabilistic regression engine
exposed via `MolADT.LogP`:

```bash
stack exec chemalgprog
```

The program parses and validates benzene and water via the façade modules,
prints their structures, and then invokes
`MolADT.LogP.runLogPRegressionWith` using both likelihood-weighted importance
sampling and Metropolis–Hastings inference. Progress updates include the actual
logP of benzene (if present in the SDF metadata) and predictions for the
database molecules.

## Next steps

- Explore the additional façade modules exported from `MolADT` for type-safe
  access to molecules and their utilities.
- Modify the example programs under `examples/` to experiment with your own
  SDF files or alternative inference settings.
