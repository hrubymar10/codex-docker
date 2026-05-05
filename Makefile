#!make
MIN_MAKE_VERSION := 3.81

ifneq ($(MIN_MAKE_VERSION),$(firstword $(sort $(MAKE_VERSION) $(MIN_MAKE_VERSION))))
$(error GNU Make $(MIN_MAKE_VERSION) or higher required)
endif

SHELL := /bin/bash
export COMPOSE_PROJECT_NAME ?= codex-docker

.DEFAULT_GOAL := help

CONTAINER     ?= codex-docker
GIT_BRANCH    := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
GIT_SHA       := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

##@ Container

.PHONY: start stop restart status rebuild shell exec beeper-start beeper-stop vscode-wrapper

start: ## Build image and start container
	@bin/codex-docker-ctrl start

stop: ## Stop container
	@bin/codex-docker-ctrl stop

restart: stop start ## Restart container

status: ## Show container status
	@bin/codex-docker-ctrl status

rebuild: ## Rebuild image from scratch and restart
	@bin/codex-docker-ctrl rebuild

shell: ## Open a shell inside the container (auto-detects from host $$SHELL)
	@bin/codex-docker-ctrl shell

exec: ## Start an interactive codex session inside the container
	@bin/codex-docker-ctrl exec

beeper-start: ## Start host beeper server
	@bin/codex-docker-ctrl beeper-start

beeper-stop: ## Stop host beeper server
	@bin/codex-docker-ctrl beeper-stop

vscode-wrapper: ## Print path to the VS Code wrapper binary
	@printf '%s/bin/codex-docker-vscode-wrapper\n' "$$(pwd)"

##@ Testing

.PHONY: test test-verbose lint

test: ## Run host-side integration tests
	@echo "Running tests (branch: $(GIT_BRANCH), $(GIT_SHA))..."
	@bash test/test-codex-docker.sh
	@bash test/test-vscode-wrapper.sh
	@bash test/test-wrappers-mock.sh
	@bash test/test-preflight-overrides.sh
	@bash test/test-compose-config.sh

test-verbose: ## Run tests with bash -x tracing
	@bash -x test/test-codex-docker.sh
	@bash -x test/test-vscode-wrapper.sh
	@bash -x test/test-wrappers-mock.sh
	@bash -x test/test-preflight-overrides.sh
	@bash -x test/test-compose-config.sh

lint: ## Run shell syntax checks
	@bash -n bin/codex-docker bin/codex-docker-ctrl bin/codex-docker-vscode-wrapper bin/lib/session-cleanup.sh scripts/*.sh

##@ Docker image

.PHONY: build-image

build-image: ## Build the Docker image without starting
	@docker compose -f docker-compose.yml build

##@ Help

.PHONY: help

help: ## Display this help screen
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
