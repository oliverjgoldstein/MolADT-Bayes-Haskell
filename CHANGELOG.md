# Changelog

## Version 2 (planned major release)

This section records the current Haskell repo state targeted as "Version 2". The package metadata still reads `0.1.0.0`; this entry is a major-release changelog for the repo rather than a claim that the Cabal version has already been bumped to `2.x`.

### Release framing

Version 2 is the point where the Haskell repo stops looking like a collection of molecule examples and becomes a coherent typed implementation with a stable CLI, a documented benchmark contract, a clear ownership boundary with the Python pipeline, and a reviewer-visible path from molecule parsing to aligned inference.

The central idea remains the same: MolADT is a replacement molecular representation that keeps atoms, sigma bonds, bonding systems, shells, and orbitals explicit, instead of collapsing chemistry into a legacy graph-only abstraction. What changes in Version 2 is the amount of practical surface area built around that idea.

### Added

- Added a practical top-level CLI in [`app/Main.hs`](app/Main.hs) with stable entrypoints for `demo`, `parse`, `parse-smiles`, `to-smiles`, and `infer-benchmark`.
- Added a default demo path that parses and validates the checked-in benzene and water SDF files before running aligned FreeSolv smoke inference.
- Added a benchmark-facing environment-variable contract through `MOLADT_PROCESSED_DATA_DIR`, so the Haskell baseline can be pointed at exported data without recompilation.
- Added direct CLI support for aligned benchmark inference over the Python-exported FreeSolv MolADT dataset.
- Added CLI-level inference syntax for `lwis`, `lwis:<particles>`, `mh`, and `mh:<jitter>`.
- Added a benchmark loader that reads `*_X_train.csv`, `*_X_valid.csv`, `*_X_test.csv`, `*_y_train.csv`, `*_y_valid.csv`, and `*_y_test.csv` from the processed-data directory.
- Added explicit recognition of representation suffixes such as `_smiles` and `_sdf` when reporting benchmark datasets.
- Added reporting of split sizes, target names, representation names, posterior sample counts, coefficient summaries, validation metrics, and test metrics on stdout.
- Added per-row test-set prediction output including predicted mean, actual value, residual, and posterior standard deviation.
- Added a typed `BenchmarkModel` layer for loading benchmark data, parsing inference methods, sampling parameters, and summarizing outputs.
- Added a default processed-data location that points at the sibling Python repo: `../MolADT-Bayes-Python/data/processed`.
- Added checked-in example modules for benzene, a pretty benzene rendering, diborane, and ferrocene under [`src/ExampleMolecules/`](src/ExampleMolecules).
- Added checked-in file-backed examples under [`molecules/`](molecules), including benzene and water SDFs.
- Added a separate example executable under [`examples/ParseMolecules.hs`](examples/ParseMolecules.hs) for direct parsing workflows.
- Added GitHub-native documentation under [`docs/`](docs) covering quickstart, examples, CLI/demo behavior, inference, SMILES scope, Python interop, testing, and repo layout.
- Added Makefile wrappers for the common Haskell workflows: `haskell-build`, `haskell-test`, `haskell-demo`, `haskell-infer-benchmark`, `haskell-parse`, `haskell-parse-smiles`, and `haskell-to-smiles`.
- Added interactive Makefile repair prompts for missing prerequisites so users can type `y` to install `stack` when Homebrew or `apt-get` is available.
- Added interactive Makefile repair prompts for missing processed benchmark exports so the Haskell repo can offer to generate them from the sibling Python repo.
- Added benchmark-alignment tests that verify the Haskell side can read the Python-exported `freesolv_moladt` dataset.
- Added parser-roundtrip tests that cover SDF round-trips, aromatic benzene reconstruction, bracketed water and methane rendering, and deterministic benzene SMILES output.
- Added validation QuickCheck properties that assert invariants over the molecular validator.
- Added edge-property QuickCheck coverage for canonical edge behavior and sigma insertion.

### Changed

- Changed the Haskell repo from a mostly local chemistry playground into the typed baseline consumer for the cross-repo benchmark pipeline.
- Changed the benchmark story so Haskell now aligns explicitly to Python’s exported `bayes_linear_student_t` data contract rather than rebuilding feature engineering locally.
- Changed the repo landing pages to make the representation, orbital model, aligned baseline, and Python timing ownership easier to understand at a glance.
- Changed the CLI and docs to treat the conservative SMILES subset as a deliberate boundary rather than an undocumented parser limitation.
- Changed the demo flow so it combines structural parsing with small aligned benchmark runs instead of stopping at molecule pretty-printing.
- Changed the benchmark stdout to emphasize reviewer-relevant summaries: split sizes, model alignment, posterior means, validation MAE/RMSE, and test MAE/RMSE.
- Changed the inference interface so users can switch methods from the command line without editing source files.
- Changed the repo’s day-to-day entrypoint toward `make` wrappers instead of assuming contributors already know the exact `stack` commands.
- Changed the Python interop documentation to state clearly that the Haskell side consumes train-standardized `X` matrices while keeping `y` on the original target scale.
- Changed the generated package description to target `cabal-version: 2.2` through `package.yaml` `verbatim` metadata, and verified that the full Stack build/test path still passes on the current resolver.
- Changed the ownership boundary between repos so raw dataset download, feature extraction, Stan fitting, timing, and reviewer-facing `results/` artifacts remain on the Python side.
- Changed the Haskell side into a narrower but sharper role: typed representation, validation, parsing, pretty-printing, and aligned LWIS/MH inference.
- Changed the release narrative from an internal research codebase toward something a reviewer or contributor can navigate directly from GitHub.

### Fixed

- Fixed the discoverability problem around cross-repo inference by documenting the processed-data path, dataset-prefix expectations, and supported CLI syntax directly in the repo.
- Fixed the previous ambiguity about how `parse` and `parse-smiles` differ by documenting their current behavior separately.
- Fixed the onboarding gap where new users had to know whether Python or Haskell owned a given benchmark stage.
- Fixed the friction around missing `stack` by turning a plain command-not-found failure into an interactive recovery path.
- Fixed the friction around missing benchmark exports by turning a missing-file failure into a prompt that can generate the required inputs from the Python repo.
- Fixed the documentation gap around the conservative SMILES renderer by stating clearly that diborane and ferrocene remain valid in MolADT even though they are outside the current SMILES subset.
- Fixed the repo-map gap by documenting where the core chemistry modules, examples, benchmark code, tests, and CLI entrypoints live.

### Documentation and operator experience

- Documented the Haskell repo as the typed source implementation of MolADT rather than an isolated side project.
- Documented the repo as part of a two-repo system, with full GitHub links back to the Python benchmark producer.
- Documented the common tasks in a GitHub-readable doc index rather than relying on a large monolithic README.
- Documented the quickstart path around `make haskell-build`, `make haskell-test`, `make haskell-demo`, and `make haskell-infer-benchmark`.
- Documented real examples only: benzene, water, diborane, and ferrocene.
- Documented the exact CLI forms that are implemented today instead of inventing aspirational commands.
- Documented the benchmark contract in terms of dataset prefixes, processed CSV files, and stdout summaries.
- Documented the current test suites individually so parser, validator, edge, and benchmark-alignment coverage are visible from the file tree.
- Documented the repo map so contributors can move quickly between [`app/`](app), [`src/Chem/`](src/Chem), [`src/ExampleMolecules/`](src/ExampleMolecules), [`src/BenchmarkModel.hs`](src/BenchmarkModel.hs), [`examples/`](examples), and [`test/`](test).

### Notes for the eventual package release

- The changelog entry above is intentionally written at the release level. If and when the package version is actually bumped to `2.x`, the package metadata in [`package.yaml`](package.yaml) and [`moladtbayes.cabal`](moladtbayes.cabal) should be updated to match.
- The repo now persists `cabal-version: 2.2` through hpack-compatible `verbatim` metadata instead of a hand-edited `.cabal` header, so Stack regeneration preserves the newer Cabal spec declaration.
- The Python repo remains the source of truth for raw benchmark generation, long timing runs, Stan outputs, and reviewer-facing benchmark artifacts under `results/`.
- Version 2 should be understood as the Haskell repo reaching a documented, test-backed, cross-repo-aligned state rather than as a claim that the project has become chemically complete or that the conservative SMILES boundary has disappeared.

## Earlier V1-era changes

Changes since V1 as discussed in V3 of the ARXIV paper, most changes being made in the last two weeks.

### Added
- Introduced a canonical **benzene molecule example** for clarity and pedagogical strength (#23).  
- Implemented multiple **molecule parsing examples**, demonstrating round-tripping from input formats (#24, #25).  
- Exposed the **ParserSingle module** for public-facing parsing examples (#26).  
- Introduced **Dietz-based core molecule types**, grounding the library in a rigorous theoretical foundation (#27).  
- Built an **electron-based Dietz molecule validator**, enforcing invariants at runtime (#31).  
- Added a **V2000 → Molecule parser with round-trip tests**, guaranteeing input fidelity (#32).  
- Expanded test coverage with **QuickCheck validation properties**, ensuring robustness (#34).  
- Introduced a dedicated **Chem.Validate module** for molecular validation (#37).  
- Added an **SDF reader** while deprecating the legacy parser, modernising the parsing stack (#38).  
- Added **aromatic ring detection** with regression tests, furthering model sophistication (#46).  
- Implemented **edge property tests**, increasing test depth (#47).  
- Ran a **LogP demo on water**, updating documentation with reproducible outputs (#48).  
- Represented **orbital shells explicitly** in constants, improving chemical interpretability (#49).  
- Registered the **internal coordinate module** in the build configuration, improving modularity (#50).  
- Added curated **sample molecules**, replacing undefined placeholders (#52).  
- Added an **atom shell pretty printer**, increasing transparency (#63).  
- Enabled **binary serialisation of molecules**, aiding persistence and sharing (#62).  
- Inserted extensive **explanatory commentary** throughout the codebase, improving maintainability and onboarding for contributors (#80).  
- Introduced a mechanism for **limiting the number of molecules parsed**, useful for targeted experiments and large corpus management (#78).  
- Expanded **elemental support** to include sodium, extending chemical coverage (#79).  
- Added detailed **progress reporting** during logP regression runs, improving visibility for long computations (#93).  

### Changed
- Clarified the representation of **benzene atom groups**, eliminating reliance on `uncurry` to simplify the codebase and improve semantic transparency (#97).  
- Reworked the **benzene construction pipeline** to use **explicit record literals**, making the process more declarative and resistant to hidden complexity (#98).  
- Restored a **concise benzene example** with a clearer hierarchical structure, balancing readability with scientific rigor (#99).  
- Standardised the storage of **bonding systems** as an ordered list, ensuring deterministic iteration order and more predictable downstream processing (#101).  
- Refactored molecules fully into the **Dietz bond model**, aligning program semantics with domain theory (#28).  
- Integrated **Angstrom-based coordinate parsing**, improving precision in structural handling (#29).  
- Implemented **edge helper functions** to simplify molecule structure manipulations (#30).  
- Incorporated **effective bond order semantics** into molecule helpers for chemically accurate features (#33).  
- Modernised imports and bond-handling modules to align with current best practices (#35).  
- Refactored coordinate management with **Angstrom units**, tightening numerical semantics (#36).  
- Simplified coordinate handling in the **benzene example**, making educational material easier to follow (#39).  
- Refined bond scoring and aggregation mechanisms, improving accuracy (#40).  
- Integrated **effective bond order** into molecule feature calculations (#42).  
- Pruned legacy modules and modernised entry points for a cleaner codebase (#43).  
- Introduced **nominal valence tracking**, with warnings when electron counts exceed chemical plausibility (#44).  
- Applied the **NonNegative type** to Dietz bonding electrons, enforcing correctness via the type system (#45).  
- Refined the internal definition of the **benzene molecule**, ensuring better alignment with Dietz’s theoretical model (#92).  
- Significantly enhanced the **molecule pretty printer**, producing outputs that are chemically accurate and visually structured (#81).  
- Extended the molecule pretty printer to **display bonding systems explicitly**, improving transparency (#69).  
- Refactored **logP feature helpers** to use **Massiv sums**, streamlining the array backend (#84).  
- Migrated the **LogP parser** to a **Massiv vector pipeline**, replacing prior implementations with a scalable approach (#85).  
- Parallelised **DB2 logP prediction formatting**, enabling efficient processing of large datasets (#86).  
- Integrated **modern chemical descriptors** into the logP regression pipeline, improving predictive sophistication (#87).  
- Updated the codebase for compatibility with the **latest Massiv API**, ensuring long-term stability (#88).  
- Refactored logP inference to **share coefficients across contexts**, eliminating redundancy (#94, #95, #96).  
- Enhanced logP regression by adding **hydrogen-bonding features**, **polar features**, and **nonlinear descriptors** (#58, #60, #64).  
- Increased regression robustness with **20k post-burn-in samples**, ensuring statistical soundness (#65).  
- Implemented **distribution-aware averaging** for logP predictions, improving rigor (#59).  
- Streamlined regression pipelines with tidier records and coefficient reuse (#60).  
- Refactored bond length lookup to ensure chemically accurate values (#51).  
- Imported molecule constructors for benzene builds to ensure consistency (#61).  
- Improved molecule pretty-printing and **exposed benzene data** for public use (#57).  

### Fixed
- Corrected **layout irregularities** in SDF parsers (#82).  
- Fixed **ambiguous EOL parsing** in SDF module (#54).  
- Fixed a **zipWithM constraint issue** involving MonadFail, restoring parser correctness (#55).  
- Handled **Latin1 decoding** in logP file parser, improving robustness (#56).  
- Fixed atom **shell type aliasing**, aligning imports (#53).  
- Fixed **subshell pretty printer output**, correcting rendering (#66).  
- Fixed **pattern binding error in LogPModel**, eliminating parse failures (#67).  
- Fixed call-site mismatches with the **formatSystem** pretty-printing function (#71).  
- Fixed signature mismatches in pretty-printer internals (#73).  
- Fixed Massiv usage in multiple **parser helpers**, resolving ambiguities (#89).  
- Addressed issues with Massiv’s **smapMaybe** usage in LogP parser, restoring correctness (#90).  
- Strengthened parallelism support by adding **NFData instances** for Massiv arrays and repairing inconsistencies (#91).  
- Fixed **Massiv array construction type ambiguities**, stabilising backend (#77).  

### Removed
- Removed outdated coordinate handling in benzene examples.  
- Deprecated and pruned **legacy modules**, modernising the codebase (#38, #43).  
- Removed initial Accelerate/Repa backends after standardising on **Massiv** (#72, #74, #75).  

---
