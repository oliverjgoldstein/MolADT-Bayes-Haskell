# Binary Packaging Guide

This repository now treats `Constants`, `LogPModel`, and `PrettyBenzene` as the
open components that depend on a privately distributed binary providing the
core molecule representations and algorithms.  The steps below outline how to
produce shipping artifacts once the proprietary library is available.

## 1. Build the proprietary core

1. Clone the private repository containing the closed modules (everything under
   `src/` except the three open modules) and build it as a Cabal library:

   ```bash
   cabal build lib:chemalgprog-internal
   ```

2. After the build completes, copy the resulting interface (`.hi`) files and
   static archive (`.a`) into this repository under `closed-bin/`.  The build
   products live under `dist-newstyle/build/<platform>/ghc-<version>/chemalgprog-internal-*/build`.

   ```bash
   mkdir -p closed-bin
   cp dist-newstyle/build/*/ghc-*/chemalgprog-internal-*/build/*.hi closed-bin/
   cp dist-newstyle/build/*/ghc-*/chemalgprog-internal-*/build/libHSchemalgprog-internal-*.a closed-bin/
   ```

3. When using Stack, create a static library by running:

   ```bash
   stack build --flag chemalgprog-internal:static
   stack ls dependencies | grep chemalgprog-internal
   cp $(stack path --local-install-root)/lib/libHSchemalgprog-internal-*.a closed-bin/
   ```

   The Stack invocation assumes the private package defines a `static` flag to
   request static archives.

## 2. Link the open components against the binary

With the closed binary copied into `closed-bin/`, adjust `extra-lib-dirs` and
`include-dirs` in the private build plan or pass them to Cabal directly:

```bash
cabal build lib:chemalgprog \
  --extra-lib-dirs="$(pwd)/closed-bin" \
  --extra-include-dirs="$(pwd)/closed-bin"
```

For Stack, the same paths can be exported via environment variables prior to
invocation:

```bash
export LIBRARY_PATH="$(pwd)/closed-bin:${LIBRARY_PATH}"
export C_INCLUDE_PATH="$(pwd)/closed-bin:${C_INCLUDE_PATH}"
stack build
```

## 3. Ship the executables as binaries

Once the open library resolves against the proprietary archive you can produce
redistributable executables.

### Cabal

```bash
cabal build exe:chemalgprog exe:parse-molecules exe:serialize-molecule
cabal install exe:chemalgprog exe:parse-molecules exe:serialize-molecule \
  --installdir="$(pwd)/dist/bin" \
  --overwrite-policy=always
```

The resulting binaries are placed under `dist/bin/` and can be zipped or
packaged for distribution.

### Stack

```bash
stack build
stack install --local-bin-path "$(pwd)/dist/bin"
```

Both commands rely on the local binary cache; the second copies the executables
into `dist/bin/` for shipping.

## 4. Optional stripping and verification

To reduce binary sizes and verify linkage:

```bash
strip dist/bin/chemalgprog dist/bin/parse-molecules dist/bin/serialize-molecule
ldd dist/bin/chemalgprog
```

These steps help ensure the final deliverables ship only with the required
open-source surface while all sensitive logic remains in the proprietary build.
