.PHONY: help setup bootstrap deploy update upgrade backup security test lint clean ui vault status

# Default target
.DEFAULT_GOAL := help

# Configuration
INVENTORY ?= inventory/hosts.yml
PLAYBOOK_DIR = playbooks
ANSIBLE_OPTS ?=
VAULT_PASSWORD_FILE ?= .vault_password

help:
	@echo ""
	@echo "Server-Helper - Available Commands"
	@echo "===================================="
	@echo ""
	@echo "Setup & Bootstrap:"
	@echo "  make setup                      - Run interactive setup script"
	@echo "  make bootstrap                  - Bootstrap target servers"
	@echo "  make bootstrap-host HOST=...    - Bootstrap specific host"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy                     - Deploy to all servers (site.yml)"
	@echo "  make deploy-targets             - Deploy to target servers only"
	@echo "  make deploy-host HOST=...       - Deploy to specific host"
	@echo "  make deploy-control             - Deploy to control node only"
	@echo "  make deploy-check               - Dry run deployment"
	@echo ""
	@echo "Operations:"
	@echo "  make update                     - Update all servers"
	@echo "  make upgrade                    - Upgrade Docker images"
	@echo "  make upgrade-service SERVICE=...- Upgrade specific service"
	@echo "  make backup                     - Run backups"
	@echo "  make security                   - Run security audit"
	@echo "  make restart-all                - Restart all services"
	@echo ""
	@echo "Testing & Quality:"
	@echo "  make test                       - Run all Molecule tests"
	@echo "  make test-role ROLE=...         - Test specific role"
	@echo "  make lint                       - Run linting"
	@echo "  make syntax-check               - Check playbook syntax"
	@echo ""
	@echo "UI & Monitoring:"
	@echo "  make ui                         - List service URLs"
	@echo "  make ui-all                     - Open all UIs"
	@echo "  make ui-dockge                  - Open Dockge"
	@echo "  make ui-netdata                 - Open Netdata"
	@echo "  make ui-uptime                  - Open Uptime Kuma"
	@echo ""
	@echo "Vault Management:"
	@echo "  make vault-edit [FILE=...]      - Edit vault file"
	@echo "  make vault-view [FILE=...]      - View vault file"
	@echo "  make vault-status               - Check vault status"
	@echo ""
	@echo "Status & Information:"
	@echo "  make status                     - Show service status"
	@echo "  make ping                       - Ping all hosts"
	@echo "  make list-hosts                 - List inventory hosts"
	@echo "  make version                    - Show version info"
	@echo ""
	@echo "Dependencies:"
	@echo "  make install-deps               - Install all dependencies"
	@echo "  make install-test-deps          - Install test dependencies"
	@echo ""
	@echo "Examples:"
	@echo "  make deploy-host HOST=server-01"
	@echo "  make test-role ROLE=common"
	@echo "  make upgrade-service SERVICE=netdata"
	@echo ""

install-test-deps:
	@echo "Installing test dependencies..."
	@echo "Installing apt packages..."
	@sudo apt-get install -y -qq pipx python3-pytest python3-docker yamllint ansible-lint || true
	@echo "Installing molecule via pipx (PEP 668 compliant)..."
	pipx install molecule || pipx upgrade molecule
	pipx inject molecule molecule-plugins[docker] pytest-testinfra ansible
	@echo "Installing required Ansible collections to ~/.ansible/collections..."
	@mkdir -p ~/.ansible/collections
	~/.local/share/pipx/venvs/molecule/bin/ansible-galaxy collection install ansible.posix community.general community.docker -p ~/.ansible/collections --force
	@echo "Done! Run 'pipx ensurepath' if molecule command is not found."

test:
	@bash scripts/lib/testing.sh test-all

test-all:
	@bash scripts/lib/testing.sh test-all

test-role:
ifndef ROLE
	@echo "Error: ROLE variable not set"
	@echo "Usage: make test-role ROLE=<role-name> [CMD=<molecule-command>]"
	@exit 1
endif
	@bash scripts/lib/testing.sh test-role $(ROLE) $(CMD)

lint:
	@echo "Running ansible-lint..."
	ansible-lint playbooks/ roles/
	@echo ""
	@echo "Running yamllint..."
	yamllint -c .yamllint playbooks/ roles/ inventory/
	@echo ""
	@echo "Lint checks passed!"

syntax-check:
	@echo "Checking playbook syntax..."
	@for playbook in playbooks/*.yml; do \
		echo "Checking $$playbook..."; \
		ansible-playbook --syntax-check "$$playbook" -i inventory/hosts.example.yml; \
	done
	@echo "Syntax check passed!"

clean:
	@echo "Cleaning up test artifacts..."
	find roles -type d -name ".molecule" -exec rm -rf {} + 2>/dev/null || true
	find roles -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find roles -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.pyc" -delete 2>/dev/null || true
	@echo "Cleanup complete!"

##@ Setup & Bootstrap

setup:
	@echo "Running setup script..."
	@bash setup.sh

bootstrap:
	@echo "Bootstrapping target servers..."
	@ansible-playbook $(PLAYBOOK_DIR)/bootstrap.yml --ask-become-pass $(ANSIBLE_OPTS)

bootstrap-host:
	@echo "Bootstrapping host: $(HOST)..."
	@ansible-playbook $(PLAYBOOK_DIR)/bootstrap.yml --limit $(HOST) --ask-become-pass $(ANSIBLE_OPTS)

##@ Deployment

deploy:
	@echo "Deploying to all servers..."
	@ansible-playbook $(PLAYBOOK_DIR)/site.yml $(ANSIBLE_OPTS)

deploy-targets:
	@echo "Deploying to target servers..."
	@ansible-playbook $(PLAYBOOK_DIR)/target.yml $(ANSIBLE_OPTS)

deploy-host:
	@echo "Deploying to host: $(HOST)..."
	@ansible-playbook $(PLAYBOOK_DIR)/site.yml --limit $(HOST) $(ANSIBLE_OPTS)

deploy-control:
	@echo "Deploying to control node..."
	@ansible-playbook $(PLAYBOOK_DIR)/control.yml $(ANSIBLE_OPTS)

deploy-check:
	@echo "Running deployment in check mode..."
	@ansible-playbook $(PLAYBOOK_DIR)/site.yml --check --diff $(ANSIBLE_OPTS)

##@ Operations

update:
	@echo "Updating all servers..."
	@ansible-playbook $(PLAYBOOK_DIR)/update.yml $(ANSIBLE_OPTS)

update-host:
	@echo "Updating host: $(HOST)..."
	@ansible-playbook $(PLAYBOOK_DIR)/update.yml --limit $(HOST) $(ANSIBLE_OPTS)

upgrade:
	@echo "Upgrading Docker images..."
	@ansible-playbook $(PLAYBOOK_DIR)/upgrade.yml $(ANSIBLE_OPTS)

upgrade-service:
	@echo "Upgrading service: $(SERVICE)..."
	@ansible-playbook $(PLAYBOOK_DIR)/upgrade.yml -e "target_service=$(SERVICE)" $(ANSIBLE_OPTS)

backup:
	@echo "Running backups..."
	@ansible-playbook $(PLAYBOOK_DIR)/backup.yml $(ANSIBLE_OPTS)

backup-host:
	@echo "Running backup on host: $(HOST)..."
	@ansible-playbook $(PLAYBOOK_DIR)/backup.yml --limit $(HOST) $(ANSIBLE_OPTS)

security:
	@echo "Running security audit (Lynis scan)..."
	@ansible all -m shell -a "sudo lynis audit system --quick" $(ANSIBLE_OPTS)

security-host:
	@echo "Running security audit on host: $(HOST)..."
	@ansible $(HOST) -m shell -a "sudo lynis audit system --quick" $(ANSIBLE_OPTS)

restart-all:
	@echo "Restarting all Docker services..."
	@ansible all -m shell -a "for d in /opt/stacks/*/; do cd \"\$$d\" && docker compose restart 2>/dev/null || true; done" $(ANSIBLE_OPTS)
	@echo "All services restarted!"

##@ UI & Monitoring

ui:
	@bash scripts/open-ui.sh list

ui-all:
	@bash scripts/open-ui.sh all

ui-dockge:
	@bash scripts/open-ui.sh dockge

ui-netdata:
	@bash scripts/open-ui.sh netdata

ui-uptime:
	@bash scripts/open-ui.sh uptime-kuma

##@ Vault Management

vault-init:
	@echo "Initializing Ansible Vault..."
	@bash scripts/lib/vault_mgr.sh init

vault-edit:
	@echo "Editing vault file..."
	@bash scripts/lib/vault_mgr.sh edit $(or $(FILE),group_vars/vault.yml)

vault-view:
	@bash scripts/lib/vault_mgr.sh view $(or $(FILE),group_vars/vault.yml)

vault-encrypt:
	@echo "Encrypting file: $(FILE)..."
	@bash scripts/lib/vault_mgr.sh encrypt $(FILE)

vault-rekey:
	@echo "Changing vault password..."
	@bash scripts/lib/vault_mgr.sh rekey --all

vault-status:
	@bash scripts/lib/vault_mgr.sh status

vault-validate:
	@bash scripts/lib/vault_mgr.sh validate

##@ Status & Information

status:
	@echo "Checking service status..."
	@ansible all -m shell -a "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" $(ANSIBLE_OPTS)

status-host:
	@echo "Checking status on host: $(HOST)..."
	@ansible $(HOST) -m shell -a "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" $(ANSIBLE_OPTS)

ping:
	@echo "Pinging all hosts..."
	@ansible all -m ping $(ANSIBLE_OPTS)

ping-host:
	@ansible $(HOST) -m ping $(ANSIBLE_OPTS)

list-hosts:
	@echo "Hosts in inventory:"
	@ansible all --list-hosts

disk-space:
	@echo "Checking disk space..."
	@ansible all -m shell -a "df -h /" $(ANSIBLE_OPTS)

version:
	@echo ""
	@echo "Server Helper v2.0.0"
	@echo ""
	@echo "Ansible: $$(ansible --version | head -1)"
	@echo "Python: $$(python3 --version)"

##@ Dependencies

install-deps:
	@echo "Installing system dependencies..."
	@sudo apt-get update -qq
	@sudo apt-get install -y -qq ansible python3-pip git curl wget sshpass
	@echo "Installing Python dependencies..."
	@sudo apt-get install -y -qq python3-docker python3-jmespath python3-netaddr python3-requests
	@echo "Installing Ansible Galaxy dependencies..."
	@ansible-galaxy install -r requirements.yml
	@echo "All dependencies installed!"

##@ Cleanup

clean-logs:
	@echo "Cleaning log files..."
	@rm -f setup.log
	@rm -f *.retry
	@echo "Log files cleaned!"

clean-docker:
	@echo "Warning: This will remove unused Docker images, containers, and volumes"
	@ansible all -m shell -a "docker system prune -af --volumes" $(ANSIBLE_OPTS)
	@echo "Docker cleanup complete!"
