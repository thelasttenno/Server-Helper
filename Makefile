.DEFAULT_GOAL := help
SHELL := /bin/bash

VERSION := $(shell cat VERSION 2>/dev/null || echo "unknown")
ANSIBLE_PLAYBOOK := ansible-playbook
ANSIBLE_VAULT := ansible-vault
ANSIBLE_LINT := ansible-lint
YAMLLINT := yamllint
MOLECULE := molecule

# Colors
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m
BOLD := \033[1m

# Input validation — reject shell metacharacters
define validate_input
$(if $(shell echo '$(2)' | grep -qE '^[a-zA-Z0-9._-]+$$' && echo ok),,$(error $(RED)SECURITY: Invalid $(1) value '$(2)'. Only [a-zA-Z0-9._-] allowed.$(RESET)))
endef

##@ General
.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "$(BOLD)Server Helper v$(VERSION)$(RESET)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BOLD)%s$(RESET)\n", substr($$0, 5) }' $(MAKEFILE_LIST)
	@echo ""

.PHONY: setup
setup: ## Run interactive setup wizard
	@bash setup.sh

.PHONY: version
version: ## Show version
	@echo "Server Helper v$(VERSION)"

##@ Deployment
.PHONY: deploy
deploy: ## Full deployment (site.yml)
	$(ANSIBLE_PLAYBOOK) playbooks/site.yml

.PHONY: deploy-control
deploy-control: ## Deploy control node only
	$(ANSIBLE_PLAYBOOK) playbooks/control.yml

.PHONY: deploy-targets
deploy-targets: ## Deploy target nodes only
	$(ANSIBLE_PLAYBOOK) playbooks/target.yml

.PHONY: deploy-host
deploy-host: ## Deploy specific host (HOST=hostname)
	@if [ -z "$(HOST)" ]; then echo "$(RED)ERROR: HOST is required. Usage: make deploy-host HOST=server1$(RESET)"; exit 1; fi
	$(call validate_input,HOST,$(HOST))
	$(ANSIBLE_PLAYBOOK) playbooks/site.yml --limit $(HOST)

.PHONY: deploy-check
deploy-check: ## Dry run of full deployment
	$(ANSIBLE_PLAYBOOK) playbooks/site.yml --check --diff

.PHONY: deploy-role
deploy-role: ## Deploy specific role (ROLE=role_name HOST=hostname)
	@if [ -z "$(ROLE)" ]; then echo "$(RED)ERROR: ROLE is required. Usage: make deploy-role ROLE=docker HOST=server1$(RESET)"; exit 1; fi
	$(call validate_input,ROLE,$(ROLE))
	$(if $(HOST),$(call validate_input,HOST,$(HOST)),)
	$(ANSIBLE_PLAYBOOK) playbooks/site.yml --tags $(ROLE) $(if $(HOST),--limit $(HOST),)

.PHONY: bootstrap
bootstrap: ## Bootstrap new target nodes
	$(ANSIBLE_PLAYBOOK) playbooks/bootstrap.yml

.PHONY: add-target
add-target: ## Add new server to fleet
	$(ANSIBLE_PLAYBOOK) playbooks/add-target.yml

##@ Updates & Upgrades
.PHONY: update
update: ## Rolling system updates
	$(ANSIBLE_PLAYBOOK) playbooks/update.yml

.PHONY: update-reboot
update-reboot: ## Rolling system updates with reboot
	$(ANSIBLE_PLAYBOOK) playbooks/update.yml --tags reboot

.PHONY: upgrade
upgrade: ## Docker image upgrades
	$(ANSIBLE_PLAYBOOK) playbooks/upgrade.yml

.PHONY: upgrade-service
upgrade-service: ## Upgrade specific service (SERVICE=name)
	@if [ -z "$(SERVICE)" ]; then echo "$(RED)ERROR: SERVICE is required. Usage: make upgrade-service SERVICE=grafana$(RESET)"; exit 1; fi
	$(call validate_input,SERVICE,$(SERVICE))
	$(ANSIBLE_PLAYBOOK) playbooks/upgrade.yml -e "target_service=$(SERVICE)"

.PHONY: upgrade-cleanup
upgrade-cleanup: ## Upgrade with image cleanup
	$(ANSIBLE_PLAYBOOK) playbooks/upgrade.yml --tags cleanup

##@ Backups
.PHONY: backup
backup: ## Trigger manual backups on all hosts
	$(ANSIBLE_PLAYBOOK) playbooks/backup.yml

.PHONY: backup-host
backup-host: ## Trigger backup on specific host (HOST=hostname)
	@if [ -z "$(HOST)" ]; then echo "$(RED)ERROR: HOST is required. Usage: make backup-host HOST=server1$(RESET)"; exit 1; fi
	$(call validate_input,HOST,$(HOST))
	$(ANSIBLE_PLAYBOOK) playbooks/backup.yml --limit $(HOST)

##@ Testing
.PHONY: test
test: ## Run all molecule tests
	@bash -c 'source scripts/lib/testing.sh && test_all_roles'

.PHONY: test-role
test-role: ## Test specific role (ROLE=role_name)
	@if [ -z "$(ROLE)" ]; then echo "$(RED)ERROR: ROLE is required. Usage: make test-role ROLE=common$(RESET)"; exit 1; fi
	$(call validate_input,ROLE,$(ROLE))
	cd roles/$(ROLE) && $(MOLECULE) test

.PHONY: test-lint
test-lint: lint ## Alias for lint

##@ Linting
.PHONY: lint
lint: lint-ansible lint-yaml ## Run all linters

.PHONY: lint-ansible
lint-ansible: ## Run ansible-lint
	$(ANSIBLE_LINT) playbooks/ roles/

.PHONY: lint-yaml
lint-yaml: ## Run yamllint
	$(YAMLLINT) -c .yamllint .

.PHONY: syntax-check
syntax-check: ## Ansible syntax check
	$(ANSIBLE_PLAYBOOK) playbooks/site.yml --syntax-check
	$(ANSIBLE_PLAYBOOK) playbooks/bootstrap.yml --syntax-check
	$(ANSIBLE_PLAYBOOK) playbooks/update.yml --syntax-check
	$(ANSIBLE_PLAYBOOK) playbooks/upgrade.yml --syntax-check
	$(ANSIBLE_PLAYBOOK) playbooks/backup.yml --syntax-check

##@ Vault
.PHONY: vault-edit
vault-edit: ## Edit encrypted vault
	$(ANSIBLE_VAULT) edit group_vars/vault.yml

.PHONY: vault-view
vault-view: ## View encrypted vault
	$(ANSIBLE_VAULT) view group_vars/vault.yml

.PHONY: vault-encrypt
vault-encrypt: ## Encrypt vault file
	$(ANSIBLE_VAULT) encrypt group_vars/vault.yml

.PHONY: vault-decrypt
vault-decrypt: ## Decrypt vault file
	$(ANSIBLE_VAULT) decrypt group_vars/vault.yml

.PHONY: vault-rekey
vault-rekey: ## Change vault password
	$(ANSIBLE_VAULT) rekey group_vars/vault.yml

##@ Fleet Management
.PHONY: ping
ping: ## Ansible ping all hosts
	ansible all -m ping

.PHONY: ping-control
ping-control: ## Ping control node
	ansible control -m ping

.PHONY: ping-targets
ping-targets: ## Ping target nodes
	ansible targets -m ping

.PHONY: status
status: ## Docker ps across fleet
	ansible all -m shell -a "docker ps --format 'table {{ '{{' }}.Names{{ '}}' }}\t{{ '{{' }}.Status{{ '}}' }}\t{{ '{{' }}.Ports{{ '}}' }}'" 2>/dev/null || true

.PHONY: facts
facts: ## Gather facts from all hosts
	ansible all -m setup --tree .ansible_cache/facts/

.PHONY: disk
disk: ## Check disk usage across fleet
	ansible all -m shell -a "df -h / | tail -1"

.PHONY: memory
memory: ## Check memory usage across fleet
	ansible all -m shell -a "free -h | grep Mem"

.PHONY: uptime
uptime: ## Check uptime across fleet
	ansible all -m shell -a "uptime"

##@ Dependencies
.PHONY: deps
deps: ## Install Ansible Galaxy dependencies
	ansible-galaxy collection install -r requirements.yml --force

.PHONY: deps-check
deps-check: ## Check if dependencies are installed
	ansible-galaxy collection list

##@ Cleanup
.PHONY: clean
clean: ## Clean temporary files
	rm -rf .ansible_cache/
	find . -name "*.retry" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

.PHONY: clean-all
clean-all: clean ## Clean everything including molecule
	find roles/ -path "*/molecule/default/.molecule" -type d -exec rm -rf {} + 2>/dev/null || true

##@ Diagnostics
.PHONY: doctor
doctor: ## Run full environment diagnostic check
	@echo ""
	@echo "$(BOLD)Server Helper v$(VERSION) — Doctor$(RESET)"
	@echo ""
	@echo "$(BOLD)Prerequisites:$(RESET)"
	@command -v python3 >/dev/null 2>&1 && echo "  $(GREEN)✓$(RESET) Python3: $$(python3 --version)" || echo "  $(RED)✗$(RESET) Python3: NOT FOUND"
	@command -v ansible >/dev/null 2>&1 && echo "  $(GREEN)✓$(RESET) Ansible: $$(ansible --version | head -1)" || echo "  $(RED)✗$(RESET) Ansible: NOT FOUND"
	@command -v ansible-lint >/dev/null 2>&1 && echo "  $(GREEN)✓$(RESET) ansible-lint: $$(ansible-lint --version | head -1)" || echo "  $(YELLOW)⚠$(RESET) ansible-lint: not installed (optional)"
	@command -v docker >/dev/null 2>&1 && echo "  $(GREEN)✓$(RESET) Docker: $$(docker --version)" || echo "  $(YELLOW)⚠$(RESET) Docker: not installed (needed for molecule)"
	@command -v molecule >/dev/null 2>&1 && echo "  $(GREEN)✓$(RESET) Molecule: $$(molecule --version | head -1)" || echo "  $(YELLOW)⚠$(RESET) Molecule: not installed (optional)"
	@command -v yamllint >/dev/null 2>&1 && echo "  $(GREEN)✓$(RESET) yamllint: $$(yamllint --version)" || echo "  $(YELLOW)⚠$(RESET) yamllint: not installed (optional)"
	@echo ""
	@echo "$(BOLD)Galaxy Collections:$(RESET)"
	@ansible-galaxy collection list 2>/dev/null | grep -E "(community\.docker|community\.general|ansible\.posix)" | awk '{printf "  $(GREEN)✓$(RESET) %s %s\n", $$1, $$2}' || echo "  $(RED)✗$(RESET) Collections not installed. Run: make deps"
	@echo ""
	@echo "$(BOLD)Configuration:$(RESET)"
	@test -f group_vars/vault.yml && (head -1 group_vars/vault.yml | grep -q '$$ANSIBLE_VAULT' && echo "  $(GREEN)✓$(RESET) Vault: encrypted" || echo "  $(YELLOW)⚠$(RESET) Vault: NOT encrypted") || echo "  $(RED)✗$(RESET) Vault: group_vars/vault.yml not found"
	@test -f inventory/hosts.yml && echo "  $(GREEN)✓$(RESET) Inventory: exists" || echo "  $(RED)✗$(RESET) Inventory: inventory/hosts.yml not found"
	@test -f .vault_password && echo "  $(GREEN)✓$(RESET) Vault password file: exists" || echo "  $(YELLOW)⚠$(RESET) Vault password file: not found"
	@test -f ansible.cfg && echo "  $(GREEN)✓$(RESET) ansible.cfg: exists" || echo "  $(RED)✗$(RESET) ansible.cfg: not found"
	@echo ""
	@echo "$(BOLD)SSH Keys:$(RESET)"
	@test -f ~/.ssh/id_ed25519 && echo "  $(GREEN)✓$(RESET) Ed25519 key found" || (test -f ~/.ssh/id_rsa && echo "  $(GREEN)✓$(RESET) RSA key found" || echo "  $(YELLOW)⚠$(RESET) No SSH key found in ~/.ssh/")
	@echo ""

##@ Setup
.PHONY: git-hooks
git-hooks: ## Install git hooks
	git config core.hooksPath .githooks
	@echo "$(GREEN)✓$(RESET) Git hooks installed from .githooks/"
