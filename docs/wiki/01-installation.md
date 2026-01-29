# Installation Guide

This guide walks you through installing and configuring Server Helper from scratch.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Control Node Setup](#control-node-setup)
3. [Target Node Preparation](#target-node-preparation)
4. [Configuration](#configuration)
5. [Deployment](#deployment)
6. [Post-Installation](#post-installation)

---

## Prerequisites

### Control Node Requirements

The control node is your management machine (laptop, desktop, or dedicated server).

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| OS | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |
| RAM | 2 GB | 4 GB |
| Storage | 10 GB | 20 GB |
| Python | 3.10+ | 3.12+ |
| Network | SSH access to targets | Static IP |

### Target Node Requirements

Target nodes are the servers you want to manage.

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| OS | Ubuntu 22.04 / Debian 12 | Ubuntu 24.04 LTS |
| RAM | 1 GB | 2 GB+ |
| Storage | 20 GB | 50 GB+ |
| CPU | 1 core | 2+ cores |

### Network Requirements

```
Control Node ──SSH──► Target Nodes (port 22)
Control Node ◄──────► Target Nodes (ports 3100, 19999)
Internet ────────────► Control Node (ports 80, 443)
```

---

## Control Node Setup

### Option 1: Interactive Setup (Recommended)

```bash
# Clone the repository
git clone https://github.com/yourusername/server-helper.git
cd server-helper

# Run the interactive setup
./setup.sh
```

The setup wizard will:
1. Install Ansible and dependencies
2. Guide you through configuration
3. Test connectivity to targets
4. Optionally run the deployment

### Option 2: Manual Setup

```bash
# Install system dependencies and Ansible
sudo apt update
sudo apt install -y python3 python3-pip git curl ansible ansible-lint

# Clone repository
git clone https://github.com/yourusername/server-helper.git
cd server-helper

# Install Ansible Galaxy dependencies
ansible-galaxy install -r requirements.yml
```

### Generate SSH Key (if needed)

```bash
# Generate ED25519 key (recommended)
ssh-keygen -t ed25519 -C "server-helper" -f ~/.ssh/server-helper

# Or RSA if ED25519 not supported
ssh-keygen -t rsa -b 4096 -C "server-helper" -f ~/.ssh/server-helper
```

---

## Target Node Preparation

### Option 1: Bootstrap Script (Recommended for new servers)

Run on each target node:

```bash
# Download and run bootstrap script
curl -fsSL https://raw.githubusercontent.com/yourusername/server-helper/main/bootstrap-target.sh | sudo bash
```

Or copy and run manually:

```bash
# On control node
scp bootstrap-target.sh user@target-ip:/tmp/

# On target node
sudo bash /tmp/bootstrap-target.sh
```

The bootstrap script will:
- Detect virtualization (LXC/VM/bare metal)
- Expand LVM volumes (if applicable)
- Create swap file (if applicable)
- Install QEMU guest agent (VMs only)
- Harden SSH configuration
- Create admin user with your SSH key

### Option 2: Manual Preparation

Ensure each target has:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Python (required by Ansible)
sudo apt install -y python3 python3-apt

# Create ansible user
sudo useradd -m -s /bin/bash ansible
sudo usermod -aG sudo ansible
echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible

# Add your SSH key
sudo mkdir -p /home/ansible/.ssh
sudo cp ~/.ssh/authorized_keys /home/ansible/.ssh/
sudo chown -R ansible:ansible /home/ansible/.ssh
sudo chmod 700 /home/ansible/.ssh
sudo chmod 600 /home/ansible/.ssh/authorized_keys
```

### Option 3: Ansible Bootstrap Playbook

From the control node:

```bash
# Bootstrap targets via Ansible (requires initial SSH access)
ansible-playbook playbooks/bootstrap.yml -u root --ask-pass
```

---

## Configuration

### Step 1: Create Configuration Files

```bash
# Copy example files
cp inventory/hosts.example.yml inventory/hosts.yml
cp group_vars/all.example.yml group_vars/all.yml
cp group_vars/vault.example.yml group_vars/vault.yml
```

### Step 2: Configure Inventory

Edit `inventory/hosts.yml`:

```yaml
all:
  children:
    control:
      hosts:
        control-node:
          ansible_host: 192.168.1.10

    targets:
      hosts:
        server1:
          ansible_host: 192.168.1.11

        server2:
          ansible_host: 192.168.1.12

        # LXC container example
        lxc-container:
          ansible_host: 192.168.1.20
          lvm_skip: true
          swap_skip: true
          qemu_agent_skip: true

  vars:
    ansible_python_interpreter: /usr/bin/python3
```

### Step 3: Configure Global Settings

Edit `group_vars/all.yml`:

```yaml
# Domain for all services
target_domain: "example.com"

# Timezone
target_timezone: "America/Vancouver"

# Control node IP (targets connect here)
control_node_ip: "192.168.1.10"

# SSH user
ansible_user: "ansible"

# Enable/disable services
restic_enabled: true
netdata_enabled: true
grafana_enabled: true
# ... etc
```

### Step 4: Configure Secrets

Edit `group_vars/vault.yml`:

```yaml
# Restic backup
vault_restic_password: "your-secure-password"
vault_restic_aws_access_key: "minio-access-key"
vault_restic_aws_secret_key: "minio-secret-key"

# Netdata streaming
vault_netdata_stream_api_key: "generate-with-uuidgen"

# Grafana
vault_grafana_admin_password: "grafana-admin-password"

# Pi-hole
vault_pihole_web_password: "pihole-password"

# Step-CA
vault_step_ca_provisioner_password: "step-ca-password"

# Authentik
vault_authentik_secret_key: "generate-64-char-hex"
vault_authentik_postgres_password: "postgres-password"
vault_authentik_admin_password: "authentik-admin-password"
```

### Step 5: Encrypt Secrets

```bash
# Create vault password file
openssl rand -base64 32 > .vault_password
chmod 600 .vault_password

# Encrypt vault file
ansible-vault encrypt group_vars/vault.yml
```

### Step 6: Test Connectivity

```bash
# Ping all hosts
ansible all -m ping

# Or use the validation script
./scripts/validate-fleet.sh --quick
```

---

## Deployment

### Full Deployment

Deploy everything in one command:

```bash
ansible-playbook playbooks/site.yml
```

### Staged Deployment

Deploy in stages:

```bash
# 1. Bootstrap targets (Day 0)
ansible-playbook playbooks/bootstrap.yml

# 2. Deploy target agents
ansible-playbook playbooks/target.yml

# 3. Deploy control stacks
ansible-playbook playbooks/control.yml
```

### Selective Deployment

Use tags to deploy specific components:

```bash
# Foundation only (all nodes)
ansible-playbook playbooks/site.yml --tags "tier1"

# Monitoring stack only
ansible-playbook playbooks/site.yml --tags "monitoring"

# Single role
ansible-playbook playbooks/site.yml --tags "grafana"
```

### Limit to Specific Hosts

```bash
# Single host
ansible-playbook playbooks/site.yml --limit "server1"

# Group of hosts
ansible-playbook playbooks/site.yml --limit "targets"
```

---

## Post-Installation

### 1. Verify Deployment

```bash
# Run full validation
./scripts/validate-fleet.sh

# Check service status
./scripts/validate-fleet.sh --services
```

### 2. Configure DNS

Point your domain to the control node:

```
*.example.com  →  192.168.1.10
```

Or add entries to Pi-hole's Local DNS.

### 3. Access Services

| Service | URL |
|---------|-----|
| Traefik | https://traefik.example.com |
| Grafana | https://grafana.example.com |
| Authentik | https://auth.example.com |
| Pi-hole | https://pihole.example.com |
| Dockge | https://dockge.example.com |
| Uptime Kuma | https://status.example.com |

### 4. Complete Authentik Setup

1. Navigate to https://auth.example.com
2. Login with admin credentials from vault
3. Change admin password
4. Configure OAuth providers for Grafana, etc.

See [Authentik Setup Guide](/opt/stacks/authentik/SETUP-GUIDE.md)

### 5. Install Step-CA Root Certificate

On clients that need to trust internal certificates:

```bash
# Download root CA
curl -k https://step-ca.example.com:9000/root -o /tmp/root_ca.crt

# Install (Linux)
sudo cp /tmp/root_ca.crt /usr/local/share/ca-certificates/step-ca-root.crt
sudo update-ca-certificates
```

### 6. Set Up Monitoring

1. Access Grafana at https://grafana.example.com
2. Loki and Netdata datasources are auto-provisioned
3. Import dashboards or create your own

### 7. Configure Backups

Verify restic repository is initialized:

```bash
# On any target
sudo /opt/restic/backup.sh
```

Check backup status:

```bash
# View snapshots
sudo -s
source /opt/restic/restic.env
restic snapshots
```

---

## Next Steps

- [Architecture Overview](02-architecture.md) - Understand the system design
- [Configuration Reference](03-configuration.md) - All configuration options
- [Role Reference](04-roles.md) - Detailed role documentation
- [Security Guide](05-security.md) - Security best practices
- [Troubleshooting](06-troubleshooting.md) - Common issues and solutions
