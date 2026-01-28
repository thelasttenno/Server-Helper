# Server Helper - Quick Reference

Quick commands and workflows for common Server Helper operations.

---

## 🚀 Quick Start

### First Time Setup

```bash
# Clone repository
git clone https://github.com/thelasttenno/Server-Helper.git
cd Server-Helper

# Run interactive setup (easiest)
./setup.sh

# OR manual setup
ansible-galaxy install -r requirements.yml
cp inventory/hosts.example.yml inventory/hosts.yml
./scripts/add-server.sh  # Interactive server addition
ansible-playbook playbooks/bootstrap.yml -K
ansible-playbook playbooks/setup-targets.yml
```

---

## 📋 Inventory Management

### Add New Server

```bash
# Interactive wizard (recommended)
./scripts/add-server.sh

# Add multiple servers
./scripts/add-server.sh --batch

# Show help
./scripts/add-server.sh --help
```

### View Inventory

```bash
# List all hosts
ansible-inventory --list

# List specific group
ansible-inventory --graph production

# Show host variables
ansible-inventory --host webserver01
```

### Test Connectivity

```bash
# Test all servers
ansible all -m ping

# Test specific server
ansible webserver01 -m ping

# Test specific group
ansible production -m ping
```

---

## 🔐 Vault Management

### Initialize Vault

```bash
# Create vault password and setup
./scripts/vault.sh init

# Check vault status
./scripts/vault.sh status
```

### Edit Secrets

```bash
# Edit vault file (recommended - secure)
./scripts/vault.sh edit group_vars/vault.yml

# View vault file (read-only)
./scripts/vault.sh view group_vars/vault.yml

# Validate vault
./scripts/vault.sh validate
```

### Vault Operations

```bash
# Backup vault file
./scripts/vault.sh backup group_vars/vault.yml

# Change vault password
./scripts/vault.sh rekey group_vars/vault.yml
./scripts/vault.sh rekey --all  # All encrypted files

# Show diff
./scripts/vault.sh diff group_vars/vault.yml
```

### Direct Ansible Vault Commands

```bash
# Edit encrypted file
ansible-vault edit group_vars/vault.yml

# View encrypted file
ansible-vault view group_vars/vault.yml

# Encrypt existing file
ansible-vault encrypt group_vars/secrets.yml

# Change password
ansible-vault rekey group_vars/vault.yml
```

---

## 🎯 Playbook Execution

### Main Playbooks

```bash
# Bootstrap new server (first time only)
ansible-playbook playbooks/bootstrap.yml -K

# Setup target servers (main deployment)
ansible-playbook playbooks/setup-targets.yml

# Setup control node (monitoring hub)
ansible-playbook playbooks/setup-control.yml

# Run backup
ansible-playbook playbooks/backup.yml

# Update servers (self-update)
ansible-playbook playbooks/update.yml

# Security audit
ansible-playbook playbooks/security.yml
```

### Playbook Options

```bash
# Dry run (check mode)
ansible-playbook playbooks/setup-targets.yml --check

# Run on specific host
ansible-playbook playbooks/setup-targets.yml --limit webserver01

# Run on specific group
ansible-playbook playbooks/setup-targets.yml --limit production

# Verbose output
ansible-playbook playbooks/setup-targets.yml -v    # verbose
ansible-playbook playbooks/setup-targets.yml -vv   # more verbose
ansible-playbook playbooks/setup-targets.yml -vvv  # debug

# Start at specific task
ansible-playbook playbooks/setup-targets.yml --start-at-task="Install Docker"

# Run specific tags
ansible-playbook playbooks/setup-targets.yml --tags "docker,monitoring"

# Skip specific tags
ansible-playbook playbooks/setup-targets.yml --skip-tags "backups"
```

---

## 🔧 Server Management

### Service Status

```bash
# Check all Docker containers
ansible all -m shell -a "docker ps"

# Check specific service
ansible all -m systemd -a "name=docker state=started enabled=yes"

# Check multiple services
ansible all -m shell -a "systemctl status docker dockge netdata uptime-kuma"
```

### Run Commands

```bash
# Run command on all servers
ansible all -m shell -a "uptime"

# Run command on specific server
ansible webserver01 -m shell -a "df -h"

# Run with privilege escalation
ansible all -m shell -a "systemctl restart docker" --become
```

### Copy Files

```bash
# Copy file to servers
ansible all -m copy -a "src=/path/to/local/file dest=/path/to/remote/file"

# Copy with template
ansible all -m template -a "src=template.j2 dest=/path/to/file"
```

---

## 💾 Backup & Restore

### Manual Backup

```bash
# Run backup playbook
ansible-playbook playbooks/backup.yml

# Trigger systemd backup
ansible all -m shell -a "systemctl start restic-backup.service" --become

# Check backup status
ansible all -m shell -a "systemctl status restic-backup.timer" --become
```

### Restore from Backup

```bash
# SSH to server first
ssh ansible@server-ip

# List snapshots
sudo restic -r /mnt/nas/backup/restic snapshots

# Restore specific snapshot
sudo restic -r /mnt/nas/backup/restic restore <snapshot-id> --target /tmp/restore

# Restore latest
sudo restic -r /mnt/nas/backup/restic restore latest --target /tmp/restore
```

---

## 🔒 Security

### Security Audit

```bash
# Run security playbook
ansible-playbook playbooks/security.yml

# Trigger Lynis scan
ansible all -m shell -a "systemctl start lynis-scan.service" --become

# View Lynis report
ansible all -m shell -a "cat /var/log/lynis/report.dat" --become
```

### Firewall Management

```bash
# Check UFW status
ansible all -m shell -a "ufw status" --become

# Allow port
ansible all -m ufw -a "rule=allow port=8080" --become

# Deny port
ansible all -m ufw -a "rule=deny port=3000" --become
```

---

## 🔐 Certificate Management

### Deploy Certificates

```bash
# Deploy Traefik + Smallstep CA
ansible-playbook playbooks/setup-targets.yml --tags traefik,step-ca

# Deploy only Traefik
ansible-playbook playbooks/setup-targets.yml --tags traefik

# Deploy only Smallstep CA
ansible-playbook playbooks/setup-targets.yml --tags step-ca
```

### Check Certificate Status

```bash
# View Let's Encrypt certificates
docker exec traefik cat /letsencrypt/acme.json | jq '.letsencrypt.Certificates'

# View Smallstep CA certificates
docker exec traefik cat /letsencrypt/step-ca-acme.json | jq .

# Check Traefik logs for certificate issues
docker logs traefik 2>&1 | grep -i "acme\|certificate"

# Check Smallstep CA logs
docker logs step-ca
```

### Smallstep CA Operations

```bash
# Check CA health
curl -k https://localhost:9000/health

# Get root CA certificate
curl -k https://localhost:9000/roots.pem

# View CA fingerprint
docker exec step-ca step certificate fingerprint /home/step/certs/root_ca.crt
```

### Client Certificate Installation

```bash
# Download and run install script
curl -sSL https://your-server:9000/install-root-ca.sh | bash

# Manual Linux installation
curl -k https://your-server:9000/roots.pem -o step-ca-root.crt
sudo cp step-ca-root.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# Manual macOS installation
curl -k https://your-server:9000/roots.pem -o step-ca-root.crt
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain step-ca-root.crt

# Windows (PowerShell as Admin)
Invoke-WebRequest -Uri "https://your-server:9000/roots.pem" -OutFile "step-ca-root.crt" -SkipCertificateCheck
certutil -addstore -f "ROOT" step-ca-root.crt
```

### Traefik Dashboard

```bash
# Access Traefik dashboard (internal only)
http://your-server:8080/dashboard/

# Or via internal domain
https://traefik.internal/dashboard/
```

### Troubleshooting Certificates

```bash
# Check if DNS-01 challenge is working
dig TXT _acme-challenge.yourdomain.com

# Verify certificate chain
echo | openssl s_client -connect your-server:443 2>/dev/null | openssl x509 -noout -issuer -subject

# Test HTTPS connection
curl -v https://your-service.yourdomain.com

# Force certificate renewal (Let's Encrypt)
docker exec traefik rm /letsencrypt/acme.json && docker restart traefik
```

---

## 📊 Monitoring

### Access Web Interfaces

```bash
# Dockge (container management)
http://your-server:5001

# Netdata (metrics)
http://your-server:19999

# Uptime Kuma (uptime monitoring)
http://your-server:3001
```

### View Logs

```bash
# Ansible playbook logs
ansible all -m shell -a "tail -f /var/log/ansible-pull.log" --become

# Backup logs
ansible all -m shell -a "journalctl -u restic-backup -f" --become

# Security scan logs
ansible all -m shell -a "journalctl -u lynis-scan -f" --become

# Docker logs
ansible all -m shell -a "docker logs netdata"
ansible all -m shell -a "docker logs uptime-kuma"
```

---

## 🔄 Updates

### Self-Update System

```bash
# Check self-update timer
ansible all -m shell -a "systemctl status ansible-pull.timer" --become

# View last update
ansible all -m shell -a "journalctl -u ansible-pull -n 50" --become

# Manual update
ansible all -m shell -a "systemctl start ansible-pull.service" --become
```

### Update Configuration

```bash
# Edit configuration
nano group_vars/all.yml

# Apply changes to all servers
ansible-playbook playbooks/setup-targets.yml

# Apply to specific server
ansible-playbook playbooks/setup-targets.yml --limit webserver01
```

---

## 🐛 Troubleshooting

### Check Connectivity

```bash
# Test SSH connection
ansible all -m ping

# Test with verbose output
ansible all -m ping -vvv

# Test specific server
ansible webserver01 -m ping
```

### Debugging Playbooks

```bash
# Dry run
ansible-playbook playbooks/setup-targets.yml --check

# Verbose output
ansible-playbook playbooks/setup-targets.yml -vvv

# Start from specific task
ansible-playbook playbooks/setup-targets.yml --start-at-task="Install Docker"

# Run only specific tags
ansible-playbook playbooks/setup-targets.yml --tags "docker"
```

### Check Service Status

```bash
# Docker
ansible all -m shell -a "systemctl status docker" --become

# Check if containers are running
ansible all -m shell -a "docker ps -a"

# View container logs
ansible all -m shell -a "docker logs --tail 50 netdata"
```

### View System Resources

```bash
# Disk usage
ansible all -m shell -a "df -h"

# Memory usage
ansible all -m shell -a "free -h"

# CPU info
ansible all -m shell -a "uptime"

# Running processes
ansible all -m shell -a "ps aux | head -20"
```

---

## 📁 Important Files

### Configuration Files

```
inventory/hosts.yml                  # Server inventory
group_vars/all.yml                   # Main configuration
group_vars/vault.yml                 # Encrypted secrets
.vault_password                      # Vault password file (keep secret!)
```

### Playbooks

```
playbooks/bootstrap.yml              # First-time server setup
playbooks/setup-targets.yml          # Main deployment
playbooks/setup-control.yml          # Control node setup
playbooks/backup.yml                 # Backup operations
playbooks/update.yml                 # Self-update
playbooks/security.yml               # Security audit
```

### Scripts

```
scripts/add-server.sh                # Interactive server addition
scripts/vault.sh                     # Vault management (all-in-one)
scripts/vault-edit.sh                # Edit vault file
scripts/vault-view.sh                # View vault file
scripts/vault-rekey.sh               # Change vault password
setup.sh                             # Main setup script
```

---

## 💡 Common Workflows

### Adding a New Server

```bash
# 1. Add to inventory
./scripts/add-server.sh

# 2. Test connection
ansible newserver -m ping

# 3. Bootstrap server
ansible-playbook playbooks/bootstrap.yml --limit newserver -K

# 4. Deploy services
ansible-playbook playbooks/setup-targets.yml --limit newserver
```

### Updating All Servers

```bash
# 1. Edit configuration
nano group_vars/all.yml

# 2. Run setup playbook
ansible-playbook playbooks/setup-targets.yml

# 3. Verify services
ansible all -m shell -a "docker ps"
```

### Rotating Vault Password

```bash
# 1. Backup current vault
./scripts/vault.sh backup group_vars/vault.yml

# 2. Change password
./scripts/vault.sh rekey --all

# 3. Verify new password works
./scripts/vault.sh validate
```

### Manual Backup Run

```bash
# 1. Run backup playbook
ansible-playbook playbooks/backup.yml

# 2. Verify backup completed
ansible all -m shell -a "restic -r /mnt/nas/backup/restic snapshots" --become

# 3. Check backup logs
ansible all -m shell -a "journalctl -u restic-backup -n 20" --become
```

---

## 🔗 Useful Links

- **Documentation**: [docs/](../docs/)
- **Setup Guide**: [docs/guides/setup-script.md](guides/setup-script.md)
- **Vault Guide**: [docs/guides/vault.md](guides/vault.md)
- **Testing Guide**: [docs/testing.md](../testing.md)
- **GitHub Issues**: https://github.com/thelasttenno/Server-Helper/issues

---

**Keep this reference handy for quick command lookups!**
