# Multi-Server Setup Guide

This guide explains how to manage multiple physical servers with Server Helper, including setting up an optional secondary server.

## Table of Contents

- [Overview](#overview)
- [Use Cases](#use-cases)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Configuration Details](#configuration-details)
- [Common Scenarios](#common-scenarios)
- [Troubleshooting](#troubleshooting)

## Overview

Server Helper supports managing multiple independent physical servers from a single control node. Each server:

- Runs its own Docker containers via Dockge
- Has independent monitoring via Netdata
- Maintains separate backup repositories
- Has its own security configuration
- Can be managed individually or as a group

**Important:** By default, servers are completely independent. They do not share state, containers, or configurations unless you explicitly set up replication or shared storage.

## Use Cases

### 1. **Load Distribution**
Run different services on different physical machines:
- Server 1: Web applications and databases
- Server 2: Media services and file storage
- Server 3: Development and testing

### 2. **Environment Separation**
Isolate environments on different hardware:
- Production server (high availability)
- Staging server (testing)
- Development server (experimental)

### 3. **Geographic Distribution**
Deploy servers in different locations:
- Home server (local services)
- VPS server (public-facing services)
- Office server (business applications)

### 4. **Service Isolation**
Separate critical services for security or performance:
- Public-facing services on DMZ server
- Internal services on private network server
- Backup/storage server on dedicated hardware

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Control Node                           │
│  (Your workstation or management server)                    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Uptime Kuma (Centralized Monitoring)              │    │
│  │  - Monitors all target servers                     │    │
│  │  - Aggregates health checks                        │    │
│  │  - Sends alerts                                    │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Server 01   │    │  Server 02   │    │  Server 03   │
│  (Primary)   │    │ (Secondary)  │    │  (Tertiary)  │
├──────────────┤    ├──────────────┤    ├──────────────┤
│ Dockge :5001 │    │ Dockge :5002 │    │ Dockge :5003 │
│ Netdata:19999│    │ Netdata:19998│    │ Netdata:19997│
│              │    │              │    │              │
│ Docker       │    │ Docker       │    │ Docker       │
│ Containers   │    │ Containers   │    │ Containers   │
│              │    │              │    │              │
│ Backups → NAS│    │ Backups → NAS│    │ Backups → NAS│
│ /server01    │    │ /server02    │    │ /server03    │
└──────────────┘    └──────────────┘    └──────────────┘
```

## Quick Start

### 1. Add Secondary Server to Inventory

Edit `inventory/hosts.yml`:

```yaml
all:
  hosts:
    # Primary server
    server01:
      ansible_host: 192.168.1.100
      ansible_user: ansible
      ansible_become: yes
      hostname: "docker-server-01"
      server_id: "01"

    # Secondary server
    server02:
      ansible_host: 192.168.1.101
      ansible_user: ansible
      ansible_become: yes
      hostname: "docker-server-02"
      server_id: "02"

      # Different ports to avoid conflicts
      dockge:
        port: 5002

      monitoring:
        netdata:
          port: 19998

      # Staggered backup schedule
      backups:
        schedule: "0 4 * * *"  # 4 AM (primary at 2 AM)
        destinations:
          nas:
            path: "/mnt/nas/backup/server02"
          local:
            path: "/opt/backups/server02"

  children:
    servers:
      hosts:
        server01:
        server02:
```

### 2. Bootstrap the Secondary Server

```bash
# Bootstrap SSH and Python on secondary server
ansible-playbook playbooks/bootstrap.yml --limit server02 -K

# Verify connectivity
ansible server02 -m ping
```

### 3. Deploy to Secondary Server

```bash
# Setup secondary server
ansible-playbook playbooks/setup-targets.yml --limit server02

# Or setup all servers at once
ansible-playbook playbooks/setup-targets.yml
```

### 4. Configure Monitoring

Access Uptime Kuma on your control node and add monitors for the secondary server:

- Dockge: `http://192.168.1.101:5002`
- Netdata: `http://192.168.1.101:19998`

## Configuration Details

### Per-Server Variable Overrides

You can override any configuration value per server in `inventory/hosts.yml`:

```yaml
server02:
  ansible_host: 192.168.1.101

  # System configuration
  hostname: "docker-server-02"
  timezone: "America/Chicago"  # Different timezone
  server_id: "02"

  # Service ports
  dockge:
    port: 5002

  monitoring:
    netdata:
      port: 19998
      claim_token: "different-token"  # Separate Netdata Cloud workspace

  # Backup configuration
  backups:
    schedule: "0 4 * * *"  # Different schedule
    retention:
      keep_daily: 14  # Keep more daily backups
    destinations:
      nas:
        enabled: true
        path: "/mnt/nas/backup/server02"
      s3:
        enabled: true
        bucket: "server02-backups"
      local:
        enabled: false  # Disable local backups

  # Security settings
  security:
    ufw_allowed_ports:
      - 22
      - 5002    # Dockge (different port)
      - 19998   # Netdata (different port)
      - 8080    # Additional port for this server
```

### Grouping Servers

Organize servers into logical groups for easier management:

```yaml
all:
  children:
    # By environment
    production:
      hosts:
        server01:
        server02:
      vars:
        backups:
          enabled: true

    development:
      hosts:
        server03:
      vars:
        backups:
          enabled: false

    # By location
    datacenter_east:
      hosts:
        server01:
      vars:
        timezone: "America/New_York"

    datacenter_west:
      hosts:
        server02:
      vars:
        timezone: "America/Los_Angeles"

    # By function
    webservers:
      hosts:
        server01:
        server02:

    databases:
      hosts:
        server03:
```

Then target specific groups:

```bash
# Backup only production servers
ansible-playbook playbooks/backup.yml --limit production

# Update only east coast servers
ansible all -m package -a "name=* state=latest" --limit datacenter_east -b
```

## Common Scenarios

### Scenario 1: Two Servers, Same Network

**Setup:**
- Both servers on `192.168.1.0/24`
- Access both via same domain/IP range
- Need to avoid port conflicts

**Configuration:**

```yaml
# Primary
server01:
  ansible_host: 192.168.1.100
  dockge: { port: 5001 }
  monitoring: { netdata: { port: 19999 } }

# Secondary
server02:
  ansible_host: 192.168.1.101
  dockge: { port: 5002 }
  monitoring: { netdata: { port: 19998 } }
```

**Access:**
- Server 1 Dockge: `http://192.168.1.100:5001`
- Server 2 Dockge: `http://192.168.1.101:5002`

### Scenario 2: Home + VPS Servers

**Setup:**
- Home server (internal services)
- VPS server (public services)
- Different networks, no port conflicts needed

**Configuration:**

```yaml
home-server:
  ansible_host: 192.168.1.100
  ansible_user: ansible
  hostname: "home-docker"
  dockge: { port: 5001 }
  monitoring: { netdata: { port: 19999 } }
  backups:
    schedule: "0 2 * * *"
    destinations:
      nas: { enabled: true }
      local: { enabled: true }

vps-server:
  ansible_host: vps.example.com
  ansible_user: ubuntu
  hostname: "vps-docker"
  dockge: { port: 5001 }  # Same port OK (different network)
  monitoring: { netdata: { port: 19999 } }
  backups:
    schedule: "0 3 * * *"  # Stagger by 1 hour
    destinations:
      s3: { enabled: true }  # VPS backs up to S3
      b2: { enabled: true }
```

### Scenario 3: Production + Staging + Development

**Setup:**
- Three servers for different environments
- Different backup policies
- Development doesn't need backups

**Configuration:**

```yaml
all:
  hosts:
    prod-server:
      ansible_host: 192.168.1.100
      hostname: "production"
      backups:
        schedule: "0 2 * * *"
        retention:
          keep_daily: 30
          keep_monthly: 12

    staging-server:
      ansible_host: 192.168.1.101
      hostname: "staging"
      backups:
        schedule: "0 3 * * *"
        retention:
          keep_daily: 7
          keep_monthly: 3

    dev-server:
      ansible_host: 192.168.1.102
      hostname: "development"
      backups:
        enabled: false  # No backups for dev

  children:
    production:
      hosts:
        prod-server:
      vars:
        security:
          ssh_password_authentication: false  # Stricter security

    non_production:
      hosts:
        staging-server:
        dev-server:
      vars:
        security:
          ssh_password_authentication: true  # More lenient
```

### Scenario 4: Shared NAS, Separate Repositories

**Setup:**
- Multiple servers backing up to same NAS
- Need separate backup repositories per server
- Staggered schedules to avoid NAS overload

**Configuration:**

```yaml
server01:
  backups:
    schedule: "0 2 * * *"  # 2 AM
    destinations:
      nas:
        path: "/mnt/nas/backup/server01"

server02:
  backups:
    schedule: "0 4 * * *"  # 4 AM
    destinations:
      nas:
        path: "/mnt/nas/backup/server02"

server03:
  backups:
    schedule: "0 6 * * *"  # 6 AM
    destinations:
      nas:
        path: "/mnt/nas/backup/server03"
```

## Management Commands

### Deploy and Update

```bash
# Setup all servers
ansible-playbook playbooks/setup-targets.yml

# Setup specific server
ansible-playbook playbooks/setup-targets.yml --limit server02

# Setup multiple servers
ansible-playbook playbooks/setup-targets.yml --limit server01,server02

# Setup a group
ansible-playbook playbooks/setup-targets.yml --limit production
```

### Backups

```bash
# Backup all servers
ansible-playbook playbooks/backup.yml

# Backup specific server
ansible-playbook playbooks/backup.yml --limit server02

# Manual backup on server
ansible server02 -m shell -a "/opt/scripts/backup.sh" -b
```

### Monitoring

```bash
# Check Docker status on all servers
ansible all -m shell -a "docker ps" -b

# Check Dockge status on specific server
ansible server02 -m shell -a "docker ps | grep dockge" -b

# Check disk space on all servers
ansible all -m shell -a "df -h" -b
```

### Updates

```bash
# Update packages on all servers
ansible all -m apt -a "update_cache=yes upgrade=dist" -b

# Update packages on specific server
ansible server02 -m apt -a "update_cache=yes upgrade=dist" -b

# Restart Docker on all servers
ansible all -m systemd -a "name=docker state=restarted" -b
```

### Information Gathering

```bash
# List all servers
ansible-inventory --list

# Show server details
ansible-inventory --host server02

# Test connectivity to all servers
ansible all -m ping

# Get server facts
ansible server02 -m setup
```

## Best Practices

### 1. **Port Management**

Always use unique ports if servers share the same network:

```yaml
server01:
  dockge: { port: 5001 }
  monitoring: { netdata: { port: 19999 } }

server02:
  dockge: { port: 5002 }
  monitoring: { netdata: { port: 19998 } }
```

### 2. **Backup Schedules**

Stagger backup schedules to avoid resource contention:

```yaml
server01:
  backups: { schedule: "0 2 * * *" }  # 2 AM

server02:
  backups: { schedule: "0 4 * * *" }  # 4 AM

server03:
  backups: { schedule: "0 6 * * *" }  # 6 AM
```

### 3. **Backup Paths**

Use separate backup paths per server:

```yaml
server01:
  backups:
    destinations:
      nas: { path: "/mnt/nas/backup/{{ inventory_hostname }}" }

server02:
  backups:
    destinations:
      nas: { path: "/mnt/nas/backup/{{ inventory_hostname }}" }
```

### 4. **Hostname Uniqueness**

Set unique hostnames for each server:

```yaml
server01:
  hostname: "docker-server-01"

server02:
  hostname: "docker-server-02"
```

### 5. **Centralized Monitoring**

Deploy Uptime Kuma on control node to monitor all servers:

```bash
# Setup control node monitoring
ansible-playbook playbooks/setup-control.yml
```

Then configure monitors for each server's services.

### 6. **Group Variables**

Use group variables for shared configuration:

```yaml
all:
  children:
    production:
      vars:
        backups:
          retention:
            keep_daily: 30
            keep_monthly: 12
        security:
          fail2ban_enabled: true

    development:
      vars:
        backups:
          retention:
            keep_daily: 7
        security:
          fail2ban_enabled: false
```

## Troubleshooting

### Port Conflicts

**Symptom:** Service fails to start, "port already in use" error

**Solution:** Assign unique ports per server in inventory:

```yaml
server02:
  dockge: { port: 5002 }
  monitoring: { netdata: { port: 19998 } }
```

### Backup Repository Conflicts

**Symptom:** Restic errors about repository corruption or lock issues

**Solution:** Ensure each server has a unique backup path:

```yaml
server01:
  backups:
    destinations:
      nas: { path: "/mnt/nas/backup/server01" }

server02:
  backups:
    destinations:
      nas: { path: "/mnt/nas/backup/server02" }
```

### SSH Connection Issues

**Symptom:** Ansible can't connect to secondary server

**Solution:**

1. Test SSH manually:
   ```bash
   ssh ansible@192.168.1.101
   ```

2. Check SSH key:
   ```bash
   ssh-copy-id ansible@192.168.1.101
   ```

3. Verify inventory:
   ```bash
   ansible-inventory --host server02
   ```

### Hostname Conflicts

**Symptom:** Netdata or other services showing wrong hostname

**Solution:** Set unique hostname per server:

```yaml
server02:
  hostname: "docker-server-02"
```

## Advanced Topics

### Shared Storage Between Servers

If you want servers to share data (e.g., Docker volumes on NAS):

1. Mount NAS on all servers with same paths
2. Use NFS or CIFS for shared volumes
3. Be careful with write conflicts

**Example:**

```yaml
all:
  hosts:
    server01:
      nas:
        shares:
          - mount: "/mnt/shared"
            share: "shared_data"

    server02:
      nas:
        shares:
          - mount: "/mnt/shared"
            share: "shared_data"
```

### Container Orchestration

For true clustering, consider:

- **Docker Swarm**: Built-in Docker clustering
- **Kubernetes**: Advanced orchestration (K3s for lightweight)
- **Portainer**: Manage multiple Docker hosts

Server Helper focuses on independent server management. For clustering, you'll need additional configuration beyond this scope.

### Cross-Server Networking

To allow containers on different servers to communicate:

1. Use a VPN (WireGuard, Tailscale)
2. Configure Docker overlay networks
3. Set up reverse proxy with service discovery

This requires advanced networking knowledge and is beyond the basic multi-server setup.

## Migration Guide

### Adding a Secondary Server to Existing Setup

1. **Prepare new server:**
   ```bash
   # Bootstrap
   ansible-playbook playbooks/bootstrap.yml --limit server02 -K
   ```

2. **Add to inventory:**
   Edit `inventory/hosts.yml` and add server02 configuration

3. **Deploy:**
   ```bash
   ansible-playbook playbooks/setup-targets.yml --limit server02
   ```

4. **Migrate containers (if needed):**
   - Export stack from Server 1 via Dockge
   - Import stack to Server 2 via Dockge
   - Update DNS/reverse proxy if applicable

### Removing a Server

1. **Remove from monitoring:**
   Delete monitors in Uptime Kuma

2. **Remove from inventory:**
   Comment out or delete server entry in `inventory/hosts.yml`

3. **Cleanup (optional):**
   ```bash
   # Remove Server Helper components
   ansible server02 -m shell -a "docker stop $(docker ps -aq)" -b
   ansible server02 -m shell -a "systemctl stop server-helper-backup.timer" -b
   ```

## Next Steps

- [README](../README.md) - Main documentation
- [CONTRIBUTING](../CONTRIBUTING.md) - Contribute to Server Helper
- [Scripts Quick Reference](../SCRIPTS_QUICKREF.md) - Available scripts
