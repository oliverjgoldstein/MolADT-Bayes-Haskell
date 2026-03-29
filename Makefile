DATASET_PREFIX ?= freesolv_smiles
METHOD ?= lwis
ROW_LIMIT ?= 128
PROCESSED_DATA_DIR ?= ../MolADT-Bayes-Python/data/processed

.PHONY: help haskell-build haskell-test haskell-demo haskell-infer-benchmark haskell-parse haskell-parse-smiles haskell-to-smiles

help:
	@printf "%s\n" \
	"Haskell repo targets:" \
	"  make haskell-build          Build the Haskell project" \
	"  make haskell-test           Run the Haskell test suites" \
	"  make haskell-demo           Run the demo executable" \
	"  make haskell-infer-benchmark Run the aligned LWIS/MH benchmark baseline" \
	"  make haskell-parse          Parse molecules/benzene.sdf" \
	"  make haskell-parse-smiles   Parse c1ccccc1" \
	"  make haskell-to-smiles      Render molecules/benzene.sdf to SMILES" \
	"" \
	"Current aligned benchmark configuration:" \
	"  processed_data_dir=$(PROCESSED_DATA_DIR)" \
	"  dataset_prefix=$(DATASET_PREFIX)" \
	"  method=$(METHOD)" \
	"  row_limit=$(ROW_LIMIT)"

haskell-build:
	stack build

haskell-test:
	stack test

haskell-demo:
	MOLADT_PROCESSED_DATA_DIR="$(PROCESSED_DATA_DIR)" stack run moladtbayes -- demo

haskell-infer-benchmark:
	MOLADT_PROCESSED_DATA_DIR="$(PROCESSED_DATA_DIR)" stack run moladtbayes -- infer-benchmark $(DATASET_PREFIX) $(METHOD) $(ROW_LIMIT)

haskell-parse:
	stack run moladtbayes -- parse molecules/benzene.sdf

haskell-parse-smiles:
	stack run moladtbayes -- parse-smiles "c1ccccc1"

haskell-to-smiles:
	stack run moladtbayes -- to-smiles molecules/benzene.sdf
