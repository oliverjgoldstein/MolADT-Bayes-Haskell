DATASET_PREFIX ?= freesolv_moladt
METHOD ?= lwis
ROW_LIMIT ?= 128
CSV_PATH ?= ../MolADT-Bayes-Python/data/raw/zinc/zinc15_250K_2D.csv
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

.PHONY: help haskell-check-stack haskell-check-dataset-data haskell-build haskell-test haskell-demo haskell-infer-benchmark haskell-parse haskell-parse-smiles haskell-parse-smiles-csv-timing haskell-to-smiles

help:
	@printf "%s\n" \
	"Haskell repo targets:" \
	"  make haskell-build          Build the Haskell project" \
	"  make haskell-test           Run the Haskell test suites" \
	"  make haskell-demo           Run the demo executable" \
	"  make haskell-infer-benchmark Run the aligned LWIS/MH benchmark baseline" \
	"  make haskell-parse          Parse molecules/benzene.sdf" \
	"  make haskell-parse-smiles   Parse c1ccccc1" \
	"  make haskell-parse-smiles-csv-timing Benchmark CSV field->String vs MolADT parse timing" \
	"  make haskell-to-smiles      Render molecules/benzene.sdf to SMILES" \
	"" \
	"Current aligned benchmark configuration:" \
	"  processed_data_dir=$(PROCESSED_DATA_DIR)" \
	"  missing export generation delegates to $(PYTHON_REPO_DIR)" \
	"  large (>100 MB) Python-side downloads and extractions show counts, speed, and elapsed time" \
	"  dataset_prefix=$(DATASET_PREFIX)" \
	"  method=$(METHOD)" \
	"  row_limit=$(ROW_LIMIT)" \
	"  csv_path=$(CSV_PATH)" \
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
		freesolv_*) python_target="python-benchmark-smoke" ;; \
		qm9_*) python_target="python-benchmark-qm9" ;; \
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
	"  required benchmark exports: freesolv_moladt and qm9_moladt" \
	"  stack_cmd: $(STACK_CMD)"
	@$(MAKE) --no-print-directory REQUIRED_DATASET_PREFIX="freesolv_moladt" haskell-check-dataset-data
	@$(MAKE) --no-print-directory REQUIRED_DATASET_PREFIX="qm9_moladt" haskell-check-dataset-data
	MOLADT_PROCESSED_DATA_DIR="$(PROCESSED_DATA_DIR)" $(STACK_CMD) run moladtbayes -- demo

haskell-infer-benchmark: haskell-check-stack
	@printf "%s\n" \
	"Running Haskell aligned benchmark inference." \
	"  repo: MolADT-Bayes-Haskell" \
	"  dataset_prefix: $(DATASET_PREFIX)" \
	"  method: $(METHOD)" \
	"  row_limit: $(ROW_LIMIT)" \
	"  processed_data_dir: $(PROCESSED_DATA_DIR)" \
	"  delegated Python repo for missing exports: $(PYTHON_REPO_DIR)" \
	"  stack_cmd: $(STACK_CMD)"
	@$(MAKE) --no-print-directory REQUIRED_DATASET_PREFIX="$(DATASET_PREFIX)" haskell-check-dataset-data
	MOLADT_PROCESSED_DATA_DIR="$(PROCESSED_DATA_DIR)" $(STACK_CMD) run moladtbayes -- infer-benchmark $(DATASET_PREFIX) $(METHOD) $(ROW_LIMIT)

haskell-parse: haskell-check-stack
	$(STACK_CMD) run moladtbayes -- parse molecules/benzene.sdf

haskell-parse-smiles: haskell-check-stack
	$(STACK_CMD) run moladtbayes -- parse-smiles "c1ccccc1"

haskell-parse-smiles-csv-timing: haskell-check-stack
	$(STACK_CMD) run moladtbayes -- parse-smiles-csv-timing $(CSV_PATH) $(ROW_LIMIT)

haskell-to-smiles: haskell-check-stack
	$(STACK_CMD) run moladtbayes -- to-smiles molecules/benzene.sdf
