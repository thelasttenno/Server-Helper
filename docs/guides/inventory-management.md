# Inventory Management Guide

Complete guide to managing your Ansible inventory with Server Helper.

---

## Table of Contents

- [Overview](#overview)
- [Inventory Structure](#inventory-structure)
- [Adding Servers](#adding-servers)
  - [Interactive Method (Recommended)](#interactive-method-recommended)
  - [Manual Method](#manual-method)
- [Managing Groups](#managing-groups)
- [Advanced Configuration](#advanced-configuration)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Overview

The Ansible inventory defines which servers you want to manage with Server Helper. It's the most important configuration file in your setup.

**What the inventory contains:**

- Server hostnames or IP addresses
- SSH connection details (user, port, key)
- Server groupings (production, development, etc.)
- Host-specific variables (custom hostnames, timezones)

**What doesn't go in the inventory:**

- Service configuration (use `group_vars/all.yml` instead)
- Secrets/passwords (use `group_vars/vault.yml` instead)
- Application settings (use `group_vars/all.yml` instead)

---

## Inventory Structure

The inventory is a YAML file located at `inventory/hosts.yml`:

```yaml
all:
  hosts:
    # Individual server definitions
    server01:
      ansible_host: 192.168.1.100
      ansible_user: ansible
      ansible_become: yes
      hostname: "web-prod-01"

  children:
    # Server groups
    production:
      hosts:
        server01:

  vars:
    # Global variables for all hosts
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
```

**Three main sections:**

1. **hosts**: Define individual servers
2. **children**: Organize servers into groups
3. **vars**: Set global variables

---

## Adding Servers

### Interactive Method (Recommended)

The easiest way to add servers is using the interactive script:

```bash
# Add a single server
./scripts/add-server.sh

# Add multiple servers in one session
./scripts/add-server.sh --batch
```

**What the script does:**

1. ✅ Prompts for all server details with helpful examples
2. ✅ Validates IP addresses, hostnames, and ports
3. ✅ Tests SSH connectivity before adding (optional)
4. ✅ Backs up your inventory automatically
5. ✅ Adds server to inventory with proper formatting
6. ✅ Assigns server to appropriate group
7. ✅ Shows you next steps after completion

**Example session:**

```bash
$ ./scripts/add-server.sh

╔════════════════════════════════════════════════════════════════════╗
║                 Server Helper - Add Server Tool                    ║
╚════════════════════════════════════════════════════════════════════╝

Server Name (e.g., webserver01, db-prod-01):
> webserver01

IP Address or Hostname (e.g., 192.168.1.100 or server.local):
> 192.168.1.100

SSH Username [default: ansible]:
> ansible

SSH Port [default: 22]:
> 22

Custom Hostname (leave empty to use server name 'webserver01'):
> web-prod-01

SSH Private Key Path (leave empty for default ~/.ssh/id_rsa):
>

Server Group [default: servers]:
  Common groups: servers, production, development, webservers, databases
> production

Timezone (leave empty for default in group_vars/all.yml):
  Examples: America/New_York, Europe/London, Asia/Tokyo
> America/New_York

Test SSH Connection? [Y/n]:
> y

▸ Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Server Name:    webserver01
  Host:           192.168.1.100
  User:           ansible
  Port:           22
  Hostname:       web-prod-01
  Group:          production
  Timezone:       America/New_York
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Add this server to inventory? [Y/n]:
> y

▸ Testing SSH connection to ansible@192.168.1.100:22...
✓ SSH connection successful!

✓ Backed up inventory to: backups/inventory/hosts.yml.backup.20250127_143000
▸ Adding server 'webserver01' to inventory...
✓ Server 'webserver01' added to inventory
✓ Added 'webserver01' to group 'production'

✓ Server added successfully!

ℹ Next steps:
  1. Verify inventory: ansible-inventory --list
  2. Test connection: ansible webserver01 -m ping
  3. Bootstrap server: ansible-playbook playbooks/bootstrap.yml --limit webserver01 -K
  4. Setup server: ansible-playbook playbooks/setup-targets.yml --limit webserver01
```

---

### Manual Method

For advanced users or scripting, you can edit the inventory file directly:

```bash
# Copy example if you don't have an inventory yet
cp inventory/hosts.example.yml inventory/hosts.yml

# Edit with your preferred editor
nano inventory/hosts.yml
```

**Add a server manually:**

```yaml
all:
  hosts:
    # Add your new server here
    mynewserver:
      ansible_host: 192.168.1.105
      ansible_user: ansible
      ansible_become: yes
      ansible_python_interpreter: /usr/bin/python3
      hostname: "my-new-server"

  children:
    servers:
      hosts:
        mynewserver:  # Add to group
```

**Verify your changes:**

```bash
# Check inventory syntax
ansible-inventory --list

# Test connection
ansible mynewserver -m ping
```

---

## Managing Groups

Groups let you organize and target specific sets of servers.

### Common Group Patterns

**By Environment:**

```yaml
children:
  production:
    hosts:
      web-prod-01:
      db-prod-01:
    vars:
      backups:
        enabled: true

  development:
    hosts:
      web-dev-01:
    vars:
      backups:
        enabled: false  # Don't backup dev servers
```

**By Function:**

```yaml
children:
  webservers:
    hosts:
      web01:
      web02:

  databases:
    hosts:
      db01:
      db02:

  monitoring:
    hosts:
      monitor01:
```

**By Location:**

```yaml
children:
  us_east:
    hosts:
      server01:
      server02:
    vars:
      timezone: "America/New_York"

  eu_west:
    hosts:
      server03:
    vars:
      timezone: "Europe/London"
```

### Using Groups

```bash
# Run playbook on specific group
ansible-playbook playbooks/setup-targets.yml --limit production

# Test connection to group
ansible production -m ping

# Run command on group
ansible webservers -m shell -a "uptime"

# List hosts in group
ansible-inventory --graph production
```

---

## Advanced Configuration

### Custom SSH Ports

```yaml
server01:
  ansible_host: 192.168.1.100
  ansible_port: 2222  # Custom SSH port
  ansible_user: ansible
  ansible_become: yes
```

### Custom SSH Keys

```yaml
cloud-server:
  ansible_host: cloud.example.com
  ansible_user: ubuntu
  ansible_ssh_private_key_file: ~/.ssh/cloud_key.pem
  ansible_become: yes
```

### Per-Host Variables

```yaml
server01:
  ansible_host: 192.168.1.100
  ansible_user: ansible
  ansible_become: yes
  # Override global settings for this host
  hostname: "custom-hostname"
  timezone: "Asia/Tokyo"
  dockge:
    port: 5002  # Different port than default
```

### Connection Tuning

```yaml
all:
  vars:
    # Increase timeout for slow connections
    ansible_ssh_timeout: 30

    # Enable SSH pipelining for faster execution
    ansible_ssh_pipelining: true

    # Custom SSH arguments
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
```

---

## Best Practices

### Naming Conventions

✅ **Good server names:**

- `web-prod-01`, `web-prod-02` (descriptive, numbered)
- `db-primary`, `db-replica` (role-based)
- `us-east-web01` (location + function)

❌ **Bad server names:**

- `server1`, `server2` (not descriptive)
- `my-server` (too generic)
- `192.168.1.100` (don't use IPs as names)

### Group Organization

**Organize by:**

1. **Environment** (production, staging, development)
2. **Function** (webservers, databases, monitoring)
3. **Location** (us-east, eu-west, asia-pacific)

**Example multi-level grouping:**

```yaml
children:
  # Level 1: Environment
  production:
    children:
      prod_webservers:
        hosts:
          web-prod-01:
          web-prod-02:
      prod_databases:
        hosts:
          db-prod-01:

  development:
    children:
      dev_webservers:
        hosts:
          web-dev-01:
```

### Security Best Practices

✅ **Do:**

- Use SSH keys instead of passwords
- Disable root login (`ansible_become: yes` instead)
- Use custom SSH ports for internet-facing servers
- Keep inventory in version control
- Use groups to apply consistent security settings

❌ **Don't:**

- Store passwords in inventory (use vault instead)
- Use `StrictHostKeyChecking=no` for production
- Commit SSH private keys to Git
- Use root user directly

### Inventory Management

✅ **Best practices:**

- Always backup before making changes (script does this automatically)
- Test connectivity after adding servers
- Use descriptive server names
- Document custom configurations with comments
- Keep inventory organized and consistent

```yaml
# Example with comments
all:
  hosts:
    # Production web servers - US East
    web-prod-us-01:
      ansible_host: 10.0.1.100
      ansible_user: ansible
      ansible_become: yes
      # Custom port due to security requirements
      ansible_port: 2222
```

---

## Troubleshooting

### Inventory Validation

```bash
# Check inventory syntax
ansible-inventory --list

# Validate specific group
ansible-inventory --graph production

# Show variables for specific host
ansible-inventory --host webserver01
```

### Connection Issues

**Problem: "Host unreachable" or connection timeout**

```bash
# Test basic connectivity
ping 192.168.1.100

# Test SSH manually
ssh ansible@192.168.1.100 -p 22

# Test with Ansible (verbose)
ansible webserver01 -m ping -vvv
```

**Problem: "Permission denied (publickey)"**

```bash
# Check SSH key
ls -la ~/.ssh/id_rsa

# Test with specific key
ansible webserver01 -m ping --private-key ~/.ssh/custom_key

# Bootstrap server first
ansible-playbook playbooks/bootstrap.yml --limit webserver01 -K
```

**Problem: "Server already exists in inventory"**

```bash
# Check existing server
ansible-inventory --host servername

# Remove manually from inventory/hosts.yml
# Or use different server name
```

### Inventory Backups

The add-server script automatically creates backups:

```bash
# List backups
ls -la backups/inventory/

# Restore from backup
cp backups/inventory/hosts.yml.backup.20250127_143000 inventory/hosts.yml
```

**Manual backup:**

```bash
# Create backup
cp inventory/hosts.yml inventory/hosts.yml.backup.$(date +%Y%m%d_%H%M%S)

# Or use timestamped backup directory
mkdir -p backups/inventory
cp inventory/hosts.yml backups/inventory/hosts.yml.backup.$(date +%Y%m%d_%H%M%S)
```

---

## Common Workflows

### Adding Your First Server

```bash
# 1. Add server using script
./scripts/add-server.sh

# 2. Verify it was added
ansible-inventory --list

# 3. Test connection
ansible mynewserver -m ping

# 4. If connection fails, bootstrap it
ansible-playbook playbooks/bootstrap.yml --limit mynewserver -K

# 5. Setup the server
ansible-playbook playbooks/setup-targets.yml --limit mynewserver
```

### Adding Multiple Servers

```bash
# Use batch mode
./scripts/add-server.sh --batch

# Follow prompts for each server
# When done, setup all at once
ansible-playbook playbooks/setup-targets.yml
```

### Reorganizing Groups

```bash
# 1. Backup inventory
cp inventory/hosts.yml inventory/hosts.yml.backup

# 2. Edit manually or with script
nano inventory/hosts.yml

# 3. Validate changes
ansible-inventory --list

# 4. Test with dry run
ansible-playbook playbooks/setup-targets.yml --check
```

---

## Quick Reference

### View Inventory

```bash
# List all hosts
ansible-inventory --list

# Show tree structure
ansible-inventory --graph

# Show specific host
ansible-inventory --host webserver01
```

### Test Connectivity

```bash
# All servers
ansible all -m ping

# Specific server
ansible webserver01 -m ping

# Specific group
ansible production -m ping
```

### Add Server

```bash
# Interactive
./scripts/add-server.sh

# Batch mode
./scripts/add-server.sh --batch
```

---

## See Also

- **[Quick Reference](../quick-reference.md)** - Common commands cheatsheet
- **[Setup Guide](setup-script.md)** - Initial setup instructions
- **[Command Node Guide](command-node.md)** - Multi-server management
- **[Example Inventory](../../inventory/hosts.example.yml)** - Fully commented template

---

**Questions?** Check the [troubleshooting section](#troubleshooting) or open an issue on GitHub.
