# terraform makefile is a helper to run terraform commands

# terraform install
version ?= "0.14.11"
os      ?= $(uname|tr A-Z a-z)
arch    ?= $(uname -m)

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
terraform := $(command -v terraform 2> /dev/null)
landscape := $(command -v landscape 2> /dev/null)
pre_commit :=  $(command -v pre-commit 2> /dev/null)

RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
# ...and turn them into do-nothing targets
$(eval $(RUN_ARGS):;@:)

# MAKEFILE ARGUMENTS
ifneq ($(strip $(terraform)),)
  	install_terraform ?= "true"
endif
ifneq ($(strip $(landscape)),)
	install_landscape ?= "true"
endif
ifneq ($(strip $(pre_commit)),)
	install_pre_commit ?= "true"
endif

help: usage version ## This help

usage:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

.PHONY: init
init: install

.PHONY: install
install: ## Install terraform

ifeq ($(install_terraform),"true")
	brew update
	brew tap hashicorp/tap
	HOMEBREW_NO_AUTO_UPDATE=1 brew install hashicorp/tap/terraform
endif
ifeq ($(install_landscape),"true")
	brew tap homebrew/core
	HOMEBREW_NO_AUTO_UPDATE=1 brew install terraform_landscape
endif
ifeq ($(install_pre_commit),"true")
	HOMEBREW_NO_AUTO_UPDATE=1 brew install pre-commit
	pre-commit install --allow-missing-config
endif
	terraform -chdir=infra init $(RUN_ARGS)

.PHONY: upgrade
upgrade: ## upgrade Installed
ifneq ($(install_terraform),"true")
	brew update
	brew tap hashicorp/tap
	HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade hashicorp/tap/terraform
endif
ifneq ($(install_landscape),"true")
	brew tap homebrew/core
	HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade terraform_landscape
endif
ifneq ($(install_pre_commit),"true")
	HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade pre-commit
	pre-commit install --allow-missing-config
endif
	terraform -chdir=infra init $(RUN_ARGS)

.PHONY: lint
lint: ## Lint HCL code
	pre-commit run --all-files
	terraform -chdir=infra fmt -check $(RUN_ARGS)

.PHONY: validate
validate: ## Basic syntax check
	terraform -chdir=infra validate $(RUN_ARGS)

.PHONY: show
show: ## List infra resources
	terraform -chdir=infra show $(RUN_ARGS)| landscape

.PHONY: refresh
refresh: ## Refresh infra resources
	terraform -chdir=infra refresh $(RUN_ARGS)

.PHONY: console
console: ## Console infra resources
	terraform -chdir=infra console $(RUN_ARGS)

.PHONY: import
import: ## Import infra resources
	terraform -chdir=infra import $(RUN_ARGS)

.PHONY: taint
taint: ## Taint infra resources
	terraform -chdir=infra taint $(RUN_ARGS)

.PHONY: untaint
untaint: ## Untaint infra resources
	terraform -chdir=infra untaint $(RUN_ARGS)

.PHONY: workspace
workspace: ## Workspace infra resources
	terraform -chdir=infra workspace

.PHONY: state
state: ## Inspect or change the remote state of your resources
	terraform -chdir=infra state $(RUN_ARGS)

.PHONY: plan
plan: dry-run

.PHONY: dry-run
dry-run: ## Dry run resources changes
	pre-commit run --all-files
	terraform -chdir=infra plan $(RUN_ARGS) | landscape

.PHONY: apply
apply: run

.PHONY: run
run: ## Execute resources changes
	pre-commit run --all-files
	terraform -chdir=infra apply $(RUN_ARGS)

.PHONY: destroy
destroy: # Destroy resources
	terraform -chdir=infra destroy $(RUN_ARGS)

version: ## Output the current version
	@echo
	@echo Running from $(PWD)
	@echo
	terraform --version
	landscape --version
	pre-commit --version
