DATASET_PREFIX ?= freesolv_moladt_featurized
METHOD ?= mh:0.2
ROW_LIMIT ?=
ROW_LIMIT_SCOPE := $(if $(strip $(ROW_LIMIT)),limit_$(ROW_LIMIT),full)
ROW_LIMIT_DISPLAY := $(if $(strip $(ROW_LIMIT)),$(ROW_LIMIT),full)
TARGET ?= -5.0
SEED_MOLECULE ?= water
VIEWER_INPUT ?= molecules/benzene.sdf
VIEWER_OUTPUT ?= results/viewer/$(basename $(notdir $(VIEWER_INPUT))).viewer.html
VIEWER_COLLECTION_OUTPUT ?= results/viewer/haskell-examples.viewer.html
VIEWER_EXAMPLES ?= benzene,diborane,ferrocene,morphine,water,methane
VIEWER_FORMAT ?=
VIEWER_TITLE ?=
OPEN_VIEWER ?= 0
VIEWER_FORMAT_ARG := $(if $(strip $(VIEWER_FORMAT)),--format $(VIEWER_FORMAT),)
VIEWER_TITLE_ARG := $(if $(strip $(VIEWER_TITLE)),--title "$(VIEWER_TITLE)",)
VIEWER_EXAMPLES_ARG := $(if $(strip $(VIEWER_EXAMPLES)),--examples "$(VIEWER_EXAMPLES)",)
OPEN_VIEWER_ARG := $(if $(filter 1 yes true,$(OPEN_VIEWER)),--open-viewer,)
SDF_PATH ?= ../MolADT-Bayes-Python/data/processed/zinc_timing/zinc15_250K_2D/$(ROW_LIMIT_SCOPE)/sdf_library
PROCESSED_DATA_DIR ?= ../MolADT-Bayes-Python/data/processed
PYTHON_REPO_DIR ?= ../MolADT-Bayes-Python
STACK_CMD ?= $(strip $(shell command -v stack 2>/dev/null || command -v stack.exe 2>/dev/null || printf "%s" stack))
BREW ?= brew
APT_GET ?= apt-get
SUDO ?= sudo
AUTO_FIX_PROMPT ?= 1
AUTO_APPROVE_FIXES ?= 0
TESTED_GHC := 9.6.5
TESTED_STACK_RESOLVER := lts-22.25

.PHONY: help haskell-check-stack haskell-check-dataset-data haskell-check-sdf-timing-data haskell-build haskell-test haskell-demo haskell-infer-benchmark haskell-inverse-design haskell-parse haskell-parse-smiles haskell-parse-sdf-timing haskell-to-smiles haskell-view haskell-viewer view molecule-viewer

help:
	@printf "%s\n" \
	"Haskell repo targets:" \
	"  make haskell-build          Build the Haskell project" \
	"  make haskell-test           Run the Haskell test suites" \
	"  make haskell-demo           Run the demo executable" \
	"  make haskell-infer-benchmark Run the aligned benchmark consumer" \
	"  make haskell-inverse-design Run FreeSolv inverse design from a typed seed molecule" \
	"  make haskell-parse          Parse molecules/benzene.sdf" \
	"  make haskell-parse-smiles   Parse c1ccccc1" \
	"  make haskell-to-smiles      Render molecules/benzene.sdf to SMILES" \
	"  make view                   Open a collection viewer for the built-in examples" \
	"  make haskell-viewer         Export a standalone HTML molecule viewer" \
	"  make molecule-viewer        Alias for haskell-viewer" \
	"" \
	"Current aligned benchmark configuration:" \
	"  processed_data_dir=$(PROCESSED_DATA_DIR)" \
	"  missing export generation delegates to $(PYTHON_REPO_DIR)" \
	"  large (>100 MB) Python-side downloads and extractions show counts, speed, and elapsed time" \
	"  dataset_prefix=$(DATASET_PREFIX)" \
	"  method=$(METHOD)" \
	"  inverse_design_target=$(TARGET)" \
	"  inverse_design_seed=$(SEED_MOLECULE)" \
	"  viewer_input=$(VIEWER_INPUT)" \
	"  viewer_output=$(VIEWER_OUTPUT)" \
	"  viewer_collection_output=$(VIEWER_COLLECTION_OUTPUT)" \
	"  viewer_examples=$(VIEWER_EXAMPLES)" \
	"  row_limit=$(ROW_LIMIT_DISPLAY)" \
	"" \
	"Tested toolchain versions:" \
	"  GHC=$(TESTED_GHC) Stack resolver=$(TESTED_STACK_RESOLVER)"

haskell-check-stack:
	@set -e; \
	stack_cmd="$(STACK_CMD)"; \
	brew_cmd="$(BREW)"; \
	apt_get_cmd="$(APT_GET)"; \
	sudo_cmd="$(SUDO)"; \
	prompt_fixes="$(AUTO_FIX_PROMPT)"; \
	auto_approve_fixes="$(AUTO_APPROVE_FIXES)"; \
	confirm_fix() { \
		prompt_text="$$1"; \
		if [ "$$auto_approve_fixes" = "1" ]; then \
			printf "%s\n" "$$prompt_text" "Auto-approving this repair."; \
			return 0; \
		fi; \
		if [ "$$prompt_fixes" = "0" ]; then \
			return 1; \
		fi; \
		printf "%s" "$$prompt_text"; \
		IFS= read -r response || response=""; \
		printf "%s\n" ""; \
		case "$$response" in \
			[Yy]|[Yy][Ee][Ss]) return 0 ;; \
			*) return 1 ;; \
		esac; \
	}; \
	if [ -x "$$stack_cmd" ] || command -v "$$stack_cmd" >/dev/null 2>&1; then \
		exit 0; \
	fi; \
	is_root=0; \
	if command -v id >/dev/null 2>&1 && [ "$$(id -u)" = "0" ]; then \
		is_root=1; \
	fi; \
	pkg_prefix=""; \
	if [ "$$is_root" != "1" ] && { [ -x "$$sudo_cmd" ] || command -v "$$sudo_cmd" >/dev/null 2>&1; }; then \
		pkg_prefix="$$sudo_cmd"; \
	fi; \
	install_method=""; \
	install_display=""; \
	if [ -x "$$brew_cmd" ] || command -v "$$brew_cmd" >/dev/null 2>&1; then \
		install_method="brew"; \
		install_display="$$brew_cmd install haskell-stack"; \
	elif { [ -x "$$apt_get_cmd" ] || command -v "$$apt_get_cmd" >/dev/null 2>&1; } && { [ "$$is_root" = "1" ] || [ -n "$$pkg_prefix" ]; }; then \
		install_method="apt"; \
		if [ -n "$$pkg_prefix" ]; then \
			install_display="$$pkg_prefix $$apt_get_cmd update && $$pkg_prefix $$apt_get_cmd install -y haskell-stack"; \
		else \
			install_display="$$apt_get_cmd update && $$apt_get_cmd install -y haskell-stack"; \
		fi; \
	fi; \
	if [ -n "$$install_method" ] && confirm_fix "Stack is not installed. Install it now with $$install_display? [y/N] "; then \
		case "$$install_method" in \
			brew) "$$brew_cmd" install haskell-stack ;; \
			apt) \
				if [ -n "$$pkg_prefix" ]; then \
					"$$pkg_prefix" "$$apt_get_cmd" update; \
					"$$pkg_prefix" "$$apt_get_cmd" install -y haskell-stack; \
				else \
					"$$apt_get_cmd" update; \
					"$$apt_get_cmd" install -y haskell-stack; \
				fi ;; \
		esac; \
	fi; \
	if [ -x "$$stack_cmd" ] || command -v "$$stack_cmd" >/dev/null 2>&1; then \
		exit 0; \
	fi; \
	printf "%s\n" \
		"" \
		"Stack is required for this repo." \
		"If you have Homebrew, install it with:" \
		"  brew install haskell-stack" \
		"" \
		"If you are on Debian, Ubuntu, or WSL, install it with:" \
		"  sudo apt-get update" \
		"  sudo apt-get install -y haskell-stack" \
		"" \
		"Then rerun your make target."; \
	exit 1

haskell-check-dataset-data:
	@set -e; \
	dataset_prefix="$(REQUIRED_DATASET_PREFIX)"; \
	processed_data_dir="$(PROCESSED_DATA_DIR)"; \
	python_repo_dir="$(PYTHON_REPO_DIR)"; \
	prompt_fixes="$(AUTO_FIX_PROMPT)"; \
	auto_approve_fixes="$(AUTO_APPROVE_FIXES)"; \
	required_file="$$processed_data_dir/$${dataset_prefix}_X_train.csv"; \
	confirm_fix() { \
		prompt_text="$$1"; \
		if [ "$$auto_approve_fixes" = "1" ]; then \
			printf "%s\n" "$$prompt_text" "Auto-approving this repair."; \
			return 0; \
		fi; \
		if [ "$$prompt_fixes" = "0" ]; then \
			return 1; \
		fi; \
		printf "%s" "$$prompt_text"; \
		IFS= read -r response || response=""; \
		printf "%s\n" ""; \
		case "$$response" in \
			[Yy]|[Yy][Ee][Ss]) return 0 ;; \
			*) return 1 ;; \
		esac; \
	}; \
	if [ -f "$$required_file" ]; then \
		exit 0; \
	fi; \
	python_target=""; \
	case "$$dataset_prefix" in \
		freesolv_*) python_target="freesolv" ;; \
		*) \
			printf "%s\n" \
				"" \
				"Unsupported benchmark dataset prefix: $$dataset_prefix" \
				"The Haskell benchmark consumer is now scoped to FreeSolv only." \
				"Use dataset_prefix=freesolv_moladt_featurized, then rerun this target."; \
			exit 1 ;; \
	esac; \
	if [ -n "$$python_target" ] && [ -f "$$python_repo_dir/Makefile" ] && confirm_fix "Processed benchmark exports for $$dataset_prefix are missing. Generate them now via the Python repo? [y/N] "; then \
		printf "%s\n" \
			"Delegating export generation to $$python_repo_dir/Makefile target $$python_target." \
			"Large Python-side downloads and extractions above GitHub's 100 MB limit will show byte counts, entry counts, throughput, and elapsed time."; \
		$(MAKE) -C "$$python_repo_dir" "$$python_target"; \
	fi; \
	if [ -f "$$required_file" ]; then \
		exit 0; \
	fi; \
	printf "%s\n" \
		"" \
		"Missing processed benchmark exports for $$dataset_prefix." \
		"Expected:" \
		"  $$required_file" \
		"" \
		"Generate them from the Python repo first, then rerun this target."; \
	exit 1

haskell-check-sdf-timing-data:
	@set -e; \
	sdf_path="$(SDF_PATH)"; \
	python_repo_dir="$(PYTHON_REPO_DIR)"; \
	row_limit="$(ROW_LIMIT)"; \
	row_limit_display="$(ROW_LIMIT_DISPLAY)"; \
	prompt_fixes="$(AUTO_FIX_PROMPT)"; \
	auto_approve_fixes="$(AUTO_APPROVE_FIXES)"; \
	confirm_fix() { \
		prompt_text="$$1"; \
		if [ "$$auto_approve_fixes" = "1" ]; then \
			printf "%s\n" "$$prompt_text" "Auto-approving this repair."; \
			return 0; \
		fi; \
		if [ "$$prompt_fixes" = "0" ]; then \
			return 1; \
		fi; \
		printf "%s" "$$prompt_text"; \
		IFS= read -r response || response=""; \
		printf "%s\n" ""; \
		case "$$response" in \
			[Yy]|[Yy][Ee][Ss]) return 0 ;; \
			*) return 1 ;; \
		esac; \
	}; \
	if [ -e "$$sdf_path" ]; then \
		exit 0; \
	fi; \
	if [ -f "$$python_repo_dir/Makefile" ] && confirm_fix "Cached ZINC SDF timing corpus is missing at $$sdf_path. Generate it now via the Python repo? [y/N] "; then \
		printf "%s\n" \
			"Delegating timing-corpus generation to $$python_repo_dir/Makefile target python-benchmark-zinc." \
			"This will prepare the sibling cached SDF timing library for row_limit=$$row_limit_display."; \
		$(MAKE) -C "$$python_repo_dir" python-benchmark-zinc ZINC_LIMIT="$$row_limit"; \
	fi; \
	if [ -e "$$sdf_path" ]; then \
		exit 0; \
	fi; \
	printf "%s\n" \
		"" \
		"Missing cached ZINC SDF timing corpus." \
		"Expected:" \
		"  $$sdf_path" \
		"" \
		"Generate it from the sibling Python repo first, for example:" \
		"  make -C $$python_repo_dir python-benchmark-zinc" \
		"Use ZINC_LIMIT=<n> if you want a subset instead of the full configured pass." \
		"" \
		"Then rerun this target."; \
	exit 1

haskell-build: haskell-check-stack
	@printf "%s\n" \
	"Building MolADT-Bayes-Haskell." \
	"  repo: MolADT-Bayes-Haskell" \
	"  stack_cmd: $(STACK_CMD)" \
	"  tested GHC: $(TESTED_GHC)" \
	"  tested resolver: $(TESTED_STACK_RESOLVER)"
	$(STACK_CMD) build

haskell-test: haskell-check-stack
	@printf "%s\n" \
	"Running Haskell test suites." \
	"  repo: MolADT-Bayes-Haskell" \
	"  stack_cmd: $(STACK_CMD)" \
	"  tested GHC: $(TESTED_GHC)" \
	"  tested resolver: $(TESTED_STACK_RESOLVER)"
	$(STACK_CMD) test

haskell-demo: haskell-check-stack
	@printf "%s\n" \
	"Running Haskell demo flow." \
	"  repo: MolADT-Bayes-Haskell" \
	"  processed_data_dir: $(PROCESSED_DATA_DIR)" \
	"  delegated Python repo for missing exports: $(PYTHON_REPO_DIR)" \
	"  required benchmark exports: freesolv_moladt_featurized" \
	"  stack_cmd: $(STACK_CMD)"
	@$(MAKE) --no-print-directory REQUIRED_DATASET_PREFIX="freesolv_moladt_featurized" haskell-check-dataset-data
	MOLADT_PROCESSED_DATA_DIR="$(PROCESSED_DATA_DIR)" $(STACK_CMD) run moladtbayes -- demo

haskell-infer-benchmark: haskell-check-stack
	@printf "%s\n" \
	"Running Haskell aligned benchmark inference." \
	"  repo: MolADT-Bayes-Haskell" \
	"  dataset_prefix: $(DATASET_PREFIX)" \
	"  method: $(METHOD)" \
	"  row_limit: $(ROW_LIMIT_DISPLAY)" \
	"  processed_data_dir: $(PROCESSED_DATA_DIR)" \
	"  delegated Python repo for missing exports: $(PYTHON_REPO_DIR)" \
	"  stack_cmd: $(STACK_CMD)"
	@$(MAKE) --no-print-directory REQUIRED_DATASET_PREFIX="$(DATASET_PREFIX)" haskell-check-dataset-data
	MOLADT_PROCESSED_DATA_DIR="$(PROCESSED_DATA_DIR)" $(STACK_CMD) run moladtbayes -- infer-benchmark $(DATASET_PREFIX) $(METHOD) $(ROW_LIMIT)

haskell-inverse-design: haskell-check-stack
	@printf "%s\n" \
	"Running Haskell FreeSolv inverse design." \
	"  repo: MolADT-Bayes-Haskell" \
	"  target: $(TARGET)" \
	"  seed_molecule: $(SEED_MOLECULE)" \
	"  processed_data_dir: $(PROCESSED_DATA_DIR)" \
	"  FreeSolv model artifact: latest complete run under $(PYTHON_REPO_DIR)/results/freesolv" \
	"  stack_cmd: $(STACK_CMD)"
	@$(MAKE) --no-print-directory REQUIRED_DATASET_PREFIX="freesolv_moladt_featurized" haskell-check-dataset-data
	MOLADT_PROCESSED_DATA_DIR="$(PROCESSED_DATA_DIR)" $(STACK_CMD) run moladtbayes -- inverse-design --target $(TARGET) --seed-molecule $(SEED_MOLECULE)

haskell-parse: haskell-check-stack
	$(STACK_CMD) run moladtbayes -- parse molecules/benzene.sdf

haskell-parse-smiles: haskell-check-stack
	$(STACK_CMD) run moladtbayes -- parse-smiles "c1ccccc1"

haskell-parse-sdf-timing: haskell-check-stack haskell-check-sdf-timing-data
	$(STACK_CMD) run moladtbayes -- parse-sdf-timing $(SDF_PATH) $(ROW_LIMIT)

haskell-to-smiles: haskell-check-stack
	$(STACK_CMD) run moladtbayes -- to-smiles molecules/benzene.sdf

haskell-view view: haskell-check-stack
	$(STACK_CMD) run moladtbayes -- view-examples --output "$(VIEWER_COLLECTION_OUTPUT)" $(VIEWER_TITLE_ARG) $(VIEWER_EXAMPLES_ARG) $(OPEN_VIEWER_ARG)

haskell-viewer: haskell-check-stack
	$(STACK_CMD) run moladtbayes -- view-html "$(VIEWER_INPUT)" --output "$(VIEWER_OUTPUT)" $(VIEWER_FORMAT_ARG) $(VIEWER_TITLE_ARG) $(OPEN_VIEWER_ARG)

molecule-viewer: haskell-viewer
