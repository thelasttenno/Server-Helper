# Command Node Architecture Guide

## Overview

Server Helper uses a **command node architecture** where:
- **Command Node**: Your laptop/desktop/workstation that runs Ansible to manage target servers
- **Target Nodes**: The Ubuntu servers you want to configure with Docker, monitoring, backups, etc.

This approach allows you to manage multiple servers from a central location with minimal manual intervention on target nodes.

## Architecture Diagram

```
┌───────────────────────────────┐         ┌───────────────────────────────┐
│      COMMAND NODE             │         │      TARGET NODE(S)           │
│   (Your Laptop/Desktop)       │         │   (Ubuntu 24.04 Servers)      │
│                               │         │                               │
│  ✓ Ansible installed          │         │  ✓ SSH server running         │
│  ✓ Python dependencies        │         │  ✓ Python 3 installed         │
│  ✓ Ansible Galaxy roles       │         │  ✓ Admin user with sudo       │
│  ✓ Inventory file             │  SSH    │  ✓ SSH key authentication     │
│  ✓ Configuration files        ├────────>│                               │
│  ✓ Vault with secrets         │         │  Ansible configures:          │
│                               │         │  ┌─────────────────────────┐  │
│  Run playbooks:               │         │  │ ✓ Docker                 │  │
│  $ ansible-playbook \         │         │  │ ✓ Dockge                 │  │
│      playbooks/setup.yml      │         │  │ ✓ Netdata                │  │
│                               │         │  │ ✓ Uptime Kuma            │  │
└───────────────────────────────┘         │  │ ✓ Restic Backups         │  │
                                          │  │ ✓ Security Hardening     │  │
                                          │  └─────────────────────────┘  │
                                          └───────────────────────────────┘
```

## Quick Start

### Step 1: Setup Command Node

Run this **once** on your laptop/desktop:

```bash
git clone https://github.com/thelasttenno/Server-Helper.git
cd Server-Helper
./setup.sh
```

The script will:
1. Install Ansible and dependencies on your command node
2. Prompt for target server details (IPs, hostnames, SSH users)
3. Create inventory and configuration files
4. Test SSH connectivity to target nodes
5. Optionally run bootstrap playbook for target nodes
6. Run main setup playbook to configure services

### Step 2: Bootstrap Target Nodes (if needed)

If your target nodes are fresh Ubuntu installs, you need to bootstrap them first.

#### Option A: Manual Bootstrap (Recommended for Initial Setup)

Copy and run on each target node as root:

```bash
# On target node as root:
curl -fsSL https://raw.githubusercontent.com/yourusername/Server-Helper/main/bootstrap-target.sh | sudo bash
```

OR download and run:

```bash
# On command node:
scp bootstrap-target.sh root@target-server:~/
ssh root@target-server

# On target node:
chmod +x bootstrap-target.sh
sudo ./bootstrap-target.sh
```

#### Option B: Ansible Bootstrap Playbook

From your command node (requires root SSH access to targets):

```bash
ansible-playbook playbooks/bootstrap.yml --ask-become-pass
```

### Step 3: Run Main Setup

The `setup.sh` script will automatically run this, or run manually:

```bash
ansible-playbook playbooks/setup.yml
```

## Prerequisites

### Command Node Requirements

- **OS**: Linux, macOS, or WSL2 on Windows
- **Python**: Python 3.8+
- **SSH Client**: OpenSSH or compatible
- **Disk Space**: ~500MB for Ansible and dependencies
- **Network**: Access to target nodes via SSH (port 22 or custom)

### Target Node Requirements

- **OS**: Ubuntu 24.04 LTS (recommended) or 22.04 LTS
- **RAM**: Minimum 2GB, 4GB+ recommended
- **Disk**: Minimum 20GB free space
- **Network**: Static IP or DNS hostname
- **SSH**: OpenSSH server running and accessible

## Detailed Setup Process

### 1. Command Node Installation

```bash
# Clone repository
git clone https://github.com/yourusername/Server-Helper.git
cd Server-Helper

# Run setup script
./setup.sh
```

### 2. Configuration Prompts

The setup script will prompt for:

#### Target Server Configuration
- Number of target servers
- SSH authentication method (key-based recommended)
- For each server:
  - Hostname identifier (e.g., `server-01`)
  - IP address or DNS name
  - SSH username (default: `ansible`)

#### Service Configuration
- System settings (timezone, hostname prefix)
- NAS mounts (optional)
- Backups with Restic (optional)
- Monitoring (Netdata, Uptime Kuma)
- Container management (Dockge)
- Security (fail2ban, UFW, SSH hardening)

### 3. Inventory File

Generated at `inventory/hosts.yml`:

```yaml
---
all:
  hosts:
    server-01:
      ansible_host: 192.168.1.100
      ansible_user: ansible
      ansible_become: yes
      ansible_python_interpreter: /usr/bin/python3

    server-02:
      ansible_host: 192.168.1.101
      ansible_user: ansible
      ansible_become: yes
      ansible_python_interpreter: /usr/bin/python3

  children:
    servers:
      hosts:
        server-01:
        server-02:

  vars:
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

### 4. SSH Key Setup

#### Generate SSH Key (if not exists)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

#### Copy SSH Key to Target Nodes

```bash
ssh-copy-id ansible@192.168.1.100
ssh-copy-id ansible@192.168.1.101
```

#### Test SSH Connectivity

```bash
ssh ansible@192.168.1.100 "echo 'Connected'"
```

## Managing Multiple Nodes

### Adding New Nodes

1. **Bootstrap the new node** (run on new target):
   ```bash
   curl -fsSL https://raw.githubusercontent.com/yourusername/Server-Helper/main/bootstrap-target.sh | sudo bash
   ```

2. **Update inventory** on command node (`inventory/hosts.yml`):
   ```yaml
   server-03:
     ansible_host: 192.168.1.102
     ansible_user: ansible
     ansible_become: yes
   ```

3. **Add to server group**:
   ```yaml
   children:
     servers:
       hosts:
         server-01:
         server-02:
         server-03:  # New node
   ```

4. **Run setup playbook**:
   ```bash
   ansible-playbook playbooks/setup.yml --limit server-03
   ```

### Targeting Specific Nodes

Run playbook on single node:
```bash
ansible-playbook playbooks/setup.yml --limit server-01
```

Run playbook on multiple nodes:
```bash
ansible-playbook playbooks/setup.yml --limit server-01,server-02
```

Run playbook on all nodes:
```bash
ansible-playbook playbooks/setup.yml
```

### Organizing Nodes by Function

Create groups in `inventory/hosts.yml`:

```yaml
all:
  children:
    production:
      hosts:
        server-01:
        server-02:

    development:
      hosts:
        server-03:

    monitoring:
      hosts:
        server-01:
        server-03:
```

Target specific groups:
```bash
ansible-playbook playbooks/setup.yml --limit production
ansible-playbook playbooks/setup.yml --limit monitoring
```

## Bootstrap Process Details

### What bootstrap-target.sh Does

1. Checks if running as root
2. Detects and validates OS (Ubuntu recommended)
3. Updates system packages
4. Installs Python 3 (required by Ansible)
5. Installs and enables SSH server
6. Creates admin user (default: `ansible`)
7. Configures passwordless sudo for admin user
8. Adds your SSH public key for authentication
9. Displays connection information

### What playbooks/bootstrap.yml Does

1. Installs Python 3 using `raw` module (works without Python)
2. Updates system packages
3. Installs essential packages (SSH, sudo, curl, etc.)
4. Creates admin user with sudo privileges
5. Adds SSH key from command node
6. Configures SSH security (disable root login, disable password auth)

## Common Operations

### Check Node Status

```bash
# Ping all nodes
ansible all -m ping

# Get system info
ansible all -m setup -a "filter=ansible_distribution*"

# Check disk space
ansible all -m shell -a "df -h"

# View Docker containers
ansible all -m shell -a "docker ps"
```

### Run Playbooks

```bash
# Main setup (configure all services)
ansible-playbook playbooks/setup.yml

# Run backups manually
ansible-playbook playbooks/backup.yml

# Security audit
ansible-playbook playbooks/security.yml

# System updates
ansible-playbook playbooks/update.yml

# Bootstrap new nodes
ansible-playbook playbooks/bootstrap.yml
```

### View Service URLs

After setup completes, access services at:

```
Server: server-01 (192.168.1.100)
  Dockge:      http://192.168.1.100:5001
  Netdata:     http://192.168.1.100:19999
  Uptime Kuma: http://192.168.1.100:3001

Server: server-02 (192.168.1.101)
  Dockge:      http://192.168.1.101:5001
  Netdata:     http://192.168.1.101:19999
  Uptime Kuma: http://192.168.1.101:3001
```

## Troubleshooting

### SSH Connection Issues

**Problem**: Cannot connect to target node

**Solutions**:
```bash
# Test SSH manually
ssh ansible@192.168.1.100

# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Add SSH key to target
ssh-copy-id ansible@192.168.1.100

# Use password authentication temporarily
ansible-playbook playbooks/setup.yml --ask-pass --ask-become-pass
```

### Python Not Found on Target

**Problem**: `/usr/bin/python3: No such file or directory`

**Solution**:
```bash
# Run bootstrap playbook (installs Python)
ansible-playbook playbooks/bootstrap.yml -e "ansible_python_interpreter=/usr/bin/python3" --ask-become-pass

# OR install Python manually on target
ssh root@target-server "apt-get update && apt-get install -y python3"
```

### Sudo Password Required

**Problem**: `BECOME password required but not specified`

**Solution**:
```bash
# Provide sudo password at runtime
ansible-playbook playbooks/setup.yml --ask-become-pass

# OR configure passwordless sudo on target (recommended)
echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible
```

### Host Key Verification Failed

**Problem**: `Host key verification failed`

**Solution**:
```bash
# Accept host key manually
ssh-keyscan -H 192.168.1.100 >> ~/.ssh/known_hosts

# OR disable strict host key checking (less secure)
# Already configured in inventory: ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
```

### Vault Password Issues

**Problem**: `Decryption failed`

**Solution**:
```bash
# Ensure vault password file exists
ls -la .vault_password

# Re-create vault if needed
ansible-vault decrypt group_vars/vault.yml
# Edit the file
ansible-vault encrypt group_vars/vault.yml
```

## Best Practices

### 1. Use SSH Keys (Not Passwords)

✅ Recommended:
```yaml
ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

❌ Avoid:
```yaml
ansible_ssh_pass: "{{ vault_password }}"
```

### 2. One Bootstrap User Per Node

Create dedicated `ansible` user on each target node for consistency and security.

### 3. Version Control Your Configuration

```bash
# Track changes to configuration
git add inventory/hosts.yml group_vars/all.yml
git commit -m "Add new production servers"

# Do NOT commit vault password or decrypted secrets
echo ".vault_password" >> .gitignore
echo "group_vars/vault.yml" >> .gitignore  # Or commit encrypted only
```

### 4. Test Changes on Development Nodes First

```bash
# Test on dev group first
ansible-playbook playbooks/setup.yml --limit development --check

# Apply to dev
ansible-playbook playbooks/setup.yml --limit development

# Then apply to production
ansible-playbook playbooks/setup.yml --limit production
```

### 5. Use Ansible Tags for Selective Updates

```bash
# Only update security settings
ansible-playbook playbooks/setup.yml --tags security

# Only update Docker containers
ansible-playbook playbooks/setup.yml --tags docker,dockge

# Skip backups
ansible-playbook playbooks/setup.yml --skip-tags backups
```

## Security Considerations

1. **Command Node Security**
   - Keep command node secure (it has SSH keys to all targets)
   - Use full disk encryption
   - Protect `.vault_password` file (chmod 600)
   - Don't commit secrets to Git

2. **SSH Key Management**
   - Use SSH key authentication (not passwords)
   - Use strong passphrases on SSH keys
   - Rotate SSH keys periodically
   - Use different keys for different environments (prod vs dev)

3. **Network Security**
   - Use firewall rules on command node
   - Restrict SSH access on target nodes (IP allowlist)
   - Use VPN for remote access
   - Consider bastion/jump host for production

4. **Vault Security**
   - Use strong vault password (32+ characters)
   - Rotate vault password periodically
   - Don't share vault password via insecure channels
   - Use separate vaults for different environments

## Advanced Configuration

### Using Jump Host / Bastion

```yaml
# inventory/hosts.yml
all:
  hosts:
    server-01:
      ansible_host: 192.168.1.100
      ansible_user: ansible
      ansible_ssh_common_args: '-o ProxyJump=bastion.example.com'
```

### Using Different SSH Ports

```yaml
server-01:
  ansible_host: 192.168.1.100
  ansible_port: 2222
  ansible_user: ansible
```

### Dynamic Inventory

For cloud environments (AWS, Azure, GCP), use dynamic inventory:

```bash
# Install cloud provider's Ansible plugin
ansible-galaxy collection install amazon.aws

# Use dynamic inventory
ansible-playbook playbooks/setup.yml -i aws_ec2.yml
```

## Migration from Local to Command-Node Setup

If you previously ran setup.sh on target nodes directly:

1. **Install on new command node**:
   ```bash
   git clone https://github.com/yourusername/Server-Helper.git
   cd Server-Helper
   ./setup.sh
   ```

2. **Import existing configuration**:
   - Copy `group_vars/all.yml` from old setup
   - Copy `group_vars/vault.yml` and `.vault_password`
   - Update inventory with remote hosts instead of localhost

3. **Test connection**:
   ```bash
   ansible all -m ping
   ```

4. **Re-run playbook** (will update but not break existing setup):
   ```bash
   ansible-playbook playbooks/setup.yml
   ```

## Support and Resources

- **GitHub**: https://github.com/thelasttenno/Server-Helper
- **Issues**: https://github.com/thelasttenno/Server-Helper/issues
- **Documentation**: See `README.md`, `VAULT_GUIDE.md`, `MIGRATION.md`
- **Ansible Docs**: https://docs.ansible.com/

## Summary

**Command Node Setup**:
```bash
git clone https://github.com/yourusername/Server-Helper.git
cd Server-Helper
./setup.sh
```

**Target Node Bootstrap** (run on each target):
```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/Server-Helper/main/bootstrap-target.sh | sudo bash
```

**Add More Nodes**:
1. Bootstrap new node
2. Update `inventory/hosts.yml`
3. Run `ansible-playbook playbooks/setup.yml --limit new-node`

**Manage Nodes**:
```bash
ansible all -m ping                        # Test connectivity
ansible all -m shell -a "docker ps"        # Run commands
ansible-playbook playbooks/setup.yml       # Configure all
ansible-playbook playbooks/update.yml      # Update all
```

Enjoy managing your servers with minimal manual intervention!
