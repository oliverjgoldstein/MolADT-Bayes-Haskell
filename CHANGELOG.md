# Changelog

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
