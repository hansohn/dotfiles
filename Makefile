MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := default
.DELETE_ON_ERROR:
.SUFFIXES:

# include makefiles
export SELF ?= $(MAKE)
PROJECT_PATH ?= $(shell pwd)
include $(PROJECT_PATH)/Makefile.*

REPO_NAME ?= $(shell basename $(CURDIR))

SHELL_FILES ?= install.sh server/bashrc
ZSH_FILES ?= zsh/zshenv zsh/zprofile zsh/zshrc os/darwin.zsh os/linux.zsh

#-------------------------------------------------------------------------------
# install
#-------------------------------------------------------------------------------

INSTALL_SCRIPT ?= $(PROJECT_PATH)/install.sh

## Symlink the full config into $HOME
install:
	@echo "[INFO] Installing '$(REPO_NAME)' full config."
	@$(INSTALL_SCRIPT)
.PHONY: install

## Symlink the full config, installing missing dependencies
install/bootstrap:
	@echo "[INFO] Installing '$(REPO_NAME)' full config with dependencies."
	@$(INSTALL_SCRIPT) --bootstrap
.PHONY: install/bootstrap

## Install the server profile (vim + bash, no dependencies)
install/minimal:
	@echo "[INFO] Installing '$(REPO_NAME)' server profile."
	@$(INSTALL_SCRIPT) --minimal
.PHONY: install/minimal

#-------------------------------------------------------------------------------
# uninstall
#-------------------------------------------------------------------------------

## Remove our symlinks and restore the newest backup
uninstall:
	@echo "[INFO] Uninstalling '$(REPO_NAME)'."
	@$(INSTALL_SCRIPT) --uninstall
.PHONY: uninstall

#-------------------------------------------------------------------------------
# lint
#-------------------------------------------------------------------------------

SHELLCHECK_SEVERITY ?= error

## Shellcheck the bash files
lint/shell:
	@echo "[INFO] Linting shell files with shellcheck."
	@shellcheck --severity=$(SHELLCHECK_SEVERITY) $(SHELL_FILES)
.PHONY: lint/shell

## Parse the zsh files
lint/zsh:
	@echo "[INFO] Parsing zsh files."
	@for f in $(ZSH_FILES); do zsh -n $$f || exit 1; done
.PHONY: lint/zsh

## Lint everything
lint: lint/shell lint/zsh
.PHONY: lint

#-------------------------------------------------------------------------------
# test
#-------------------------------------------------------------------------------

TEST_DOCKER_IMAGE ?= ubuntu:24.04

# Internal guard -- deliberately no '##' comment, so it stays out of help.
# It is a prerequisite of test/linux, never something you run directly.
docker/check:
	@docker info > /dev/null 2>&1 || (echo "[ERROR] Docker daemon is not running." && exit 1)
.PHONY: docker/check

## Verify the config loads cleanly on a bare Linux box
test/linux: docker/check
	@echo "[INFO] Testing '$(REPO_NAME)' on $(TEST_DOCKER_IMAGE) with no dependencies."
	@docker run --rm -v "$(CURDIR)":/dotfiles:ro $(TEST_DOCKER_IMAGE) bash -c '\
		apt-get update -qq >/dev/null 2>&1; \
		apt-get install -y -qq zsh vim >/dev/null 2>&1; \
		cp -r /dotfiles /root/dotfiles && chmod -R u+w /root/dotfiles; \
		export DOTFILES=/root/dotfiles; \
		ln -sf $$DOTFILES/zsh/zshrc /root/.zshrc; \
		ln -sf $$DOTFILES/zsh/zshenv /root/.zshenv; \
		ln -sf $$DOTFILES/zsh/zprofile /root/.zprofile; \
		err=$$(zsh -lic true 2>&1 >/dev/null); \
		if [ -n "$$err" ]; then echo "[ERROR] zsh startup wrote to stderr:"; echo "$$err"; exit 1; fi; \
		echo "[INFO] Clean startup with no dependencies."; \
		v=$$(zsh -lic "command -v vim" 2>/dev/null); \
		case "$$v" in *nvim*) echo "[ERROR] vim shadowed by missing nvim."; exit 1;; esac; \
		echo "[INFO] vim resolves to $$v."'
.PHONY: test/linux

## Verify the config loads on macOS without touching $HOME
test/macos:
	@echo "[INFO] Testing '$(REPO_NAME)' on macOS in a ZDOTDIR sandbox."
	@tmp=$$(mktemp -d); \
	ln -sf "$(CURDIR)/zsh/zshrc" "$$tmp/.zshrc"; \
	ln -sf "$(CURDIR)/zsh/zshenv" "$$tmp/.zshenv"; \
	ln -sf "$(CURDIR)/zsh/zprofile" "$$tmp/.zprofile"; \
	err=$$(ZDOTDIR="$$tmp" DOTFILES="$(CURDIR)" zsh -lic true 2>&1 >/dev/null \
		| grep -v "can.t change option: zle" || true); \
	rm -rf "$$tmp"; \
	if [ -n "$$err" ]; then echo "[ERROR] zsh startup wrote to stderr:"; echo "$$err"; exit 1; fi; \
	echo "[INFO] Clean startup, \$$HOME untouched."
.PHONY: test/macos

## Run every smoke test
test: test/macos test/linux
.PHONY: test

#-------------------------------------------------------------------------------
# validate
#-------------------------------------------------------------------------------

## Lint and test - what CI runs
validate: lint test
.PHONY: validate

#-------------------------------------------------------------------------------
# clean
#-------------------------------------------------------------------------------

## Remove installer backup directories
clean:
	@if [ -d "$(HOME)/.dotfiles-backup" ]; then \
		echo "[INFO] Removing installer backups found at '$(HOME)/.dotfiles-backup'"; \
		rm -rf "$(HOME)/.dotfiles-backup"; \
	fi
.PHONY: clean
