# Migration Guide: v0.3.0 (Bash) → v1.0.0 (Ansible)

This guide helps you migrate from Server Helper v0.3.0 (bash scripts) to v1.0.0 (Ansible playbooks).

---

## 🔄 Migration Overview

**v0.3.0** used bash scripts with manual execution and monitoring loops.
**v1.0.0** uses Ansible playbooks with declarative configuration and systemd timers.

### Major Changes

| Aspect | v0.3.0 (Bash) | v1.0.0 (Ansible) |
|--------|---------------|------------------|
| **Interface** | CLI menu + commands | Ansible playbooks + Web UIs |
| **Configuration** | Bash config file | YAML variables |
| **Monitoring** | Bash loop in systemd | Netdata + Uptime Kuma |
| **Backups** | Tar archives | Restic (encrypted, deduplicated) |
| **Container Mgmt** | Docker Compose CLI | Dockge Web UI |
| **Updates** | Git pull + bash | ansible-pull automated |
| **Security** | Manual scripts | Lynis + automated hardening |

---

## 📋 Pre-Migration Checklist

Before starting migration, gather this information:

- [ ] Current NAS configuration (IP, share, credentials)
- [ ] Current Dockge stacks and data
- [ ] Backup locations and schedules
- [ ] Uptime Kuma monitors (if configured)
- [ ] Custom scripts or modifications
- [ ] Firewall rules (UFW)
- [ ] SSH keys and access

---

## 🔍 Step 1: Export Current Configuration

### 1.1 Save Current Config

```bash
# Backup current configuration
sudo cp /opt/Server-Helper/server-helper.conf ~/server-helper-v0.3.0.conf

# View current config (passwords will be masked)
sudo /opt/Server-Helper/server_helper_setup.sh show-config > ~/current-config.txt
```

### 1.2 Export Dockge Stacks

```bash
# List current stacks
cd /opt/dockge/stacks
ls -la

# Create backup of all stacks
sudo tar -czf ~/dockge-stacks-backup.tar.gz /opt/dockge/stacks

# Document running containers
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}" > ~/running-containers.txt
```

### 1.3 Export Uptime Kuma Configuration

If you're using Uptime Kuma:

```bash
# Backup Uptime Kuma data
sudo docker exec uptime-kuma cat /app/data/kuma.db > ~/uptime-kuma-backup.db
```

### 1.4 Document Current Backups

```bash
# List current backups
ls -lh /mnt/nas/dockge_backups/

# Document backup locations
echo "NAS Backups:" > ~/backup-locations.txt
find /mnt/nas/dockge_backups -name "*.tar.gz" >> ~/backup-locations.txt
```

---

## 🗺️ Step 2: Map Configuration to Ansible

### 2.1 Configuration Mapping

Map your bash config to Ansible YAML:

**Bash (v0.3.0):**
```bash
# server-helper.conf
NAS_IP="192.168.1.100"
NAS_SHARE="backup"
NAS_USERNAME="nasuser"
NAS_PASSWORD="naspass"
DOCKGE_PORT="5001"
BACKUP_RETENTION_DAYS="30"
```

**Ansible (v1.0.0):**
```yaml
# group_vars/all.yml
nas:
  enabled: true
  shares:
    - ip: "192.168.1.100"
      share: "backup"
      mount: "/mnt/nas/backup"
      username: "nasuser"
      password: "naspass"

dockge:
  enabled: true
  port: 5001

restic:
  enabled: true
  retention:
    keep_daily: 30
```

### 2.2 Complete Mapping Table

| v0.3.0 Variable | v1.0.0 Variable | Notes |
|-----------------|-----------------|-------|
| `NEW_HOSTNAME` | `hostname` | System hostname |
| `NAS_IP` | `nas.shares[].ip` | Supports multiple shares now |
| `NAS_SHARE` | `nas.shares[].share` | - |
| `NAS_MOUNT_POINT` | `nas.shares[].mount` | - |
| `NAS_USERNAME` | `nas.shares[].username` | - |
| `NAS_PASSWORD` | `nas.shares[].password` | - |
| `DOCKGE_PORT` | `dockge.port` | - |
| `DOCKGE_DATA_DIR` | `dockge.data_dir` | - |
| `BACKUP_DIR` | `restic.destinations.nas.path` | Now uses Restic |
| `BACKUP_RETENTION_DAYS` | `restic.retention.keep_daily` | More granular options |
| `DISK_CLEANUP_THRESHOLD` | - | Handled by Netdata alarms |
| `AUTO_UPDATE_ENABLED` | `self_update.enabled` | Now uses ansible-pull |
| `FAIL2BAN_ENABLED` | `security.fail2ban_enabled` | - |
| `UFW_ENABLED` | `security.ufw_enabled` | - |
| `SSH_HARDENING_ENABLED` | `security.ssh_hardening` | - |

---

## 🚀 Step 3: Install Ansible Version

### 3.1 Stop Old System

```bash
# Stop old monitoring service
sudo systemctl stop server-helper
sudo systemctl disable server-helper

# Don't uninstall yet - we'll migrate data first
```

### 3.2 Install Ansible (if not already)

```bash
# On Ubuntu 24.04
sudo apt update
sudo apt install -y ansible python3-pip git

# Verify
ansible --version
```

### 3.3 Clone New Repository

```bash
# Clone to new location
cd /opt
sudo git clone https://github.com/thelasttenno/Server-Helper.git Server-Helper-Ansible
cd Server-Helper-Ansible
sudo git checkout v1.0.0

# Install requirements
ansible-galaxy install -r requirements.yml
pip3 install -r requirements.txt
```

### 3.4 Configure Inventory

```bash
# Create inventory
sudo cp inventory/hosts.example.yml inventory/hosts.yml
sudo nano inventory/hosts.yml

# Set your server details
all:
  hosts:
    server01:
      ansible_host: 192.168.1.100  # Your server IP (or localhost)
      ansible_user: ubuntu          # Your SSH user
```

### 3.5 Configure Variables

```bash
# Copy example config
sudo cp group_vars/all.example.yml group_vars/all.yml

# Edit with your settings (use mapping from Step 2)
sudo nano group_vars/all.yml

# Key settings to configure:
# - hostname
# - nas (if used)
# - restic (backup destinations)
# - netdata (monitoring)
# - uptime_kuma (alerting)
# - security (firewall, fail2ban, ssh)
```

---

## 📦 Step 4: Migrate Data

### 4.1 Migrate Dockge Stacks

The new system will create fresh Dockge stacks, but you can preserve your custom ones:

```bash
# After running Ansible setup (Step 5), restore custom stacks:
sudo cp -r /opt/dockge/stacks/your-custom-stack /opt/dockge/stacks/
```

### 4.2 Migrate Backups to Restic (Optional)

If you want to use Restic with your existing backups:

```bash
# Initialize Restic repository
sudo restic -r /mnt/nas/backup/restic init

# You can't directly migrate tar backups to Restic
# Instead, run a new backup after setup
# Old tar backups remain available for recovery
```

### 4.3 Migrate Uptime Kuma Data (If Used)

```bash
# After Ansible deploys Uptime Kuma, restore data:
sudo docker cp ~/uptime-kuma-backup.db uptime-kuma:/app/data/kuma.db
sudo docker restart uptime-kuma
```

---

## ▶️ Step 5: Run Ansible Setup

### 5.1 Dry Run (Check Mode)

```bash
cd /opt/Server-Helper-Ansible

# Test run (no changes)
ansible-playbook playbooks/setup.yml --check
```

### 5.2 Full Setup

```bash
# Run full setup
ansible-playbook playbooks/setup.yml

# With verbose output for troubleshooting
ansible-playbook playbooks/setup.yml -v
```

### 5.3 Verify Deployment

```bash
# Check Docker containers
docker ps

# Expected containers:
# - dockge
# - netdata
# - uptime-kuma
# (plus any optional services you enabled)

# Check systemd timers
sudo systemctl list-timers

# Expected timers:
# - restic-backup.timer
# - lynis-scan.timer (if security.lynis_enabled)
# - ansible-pull.timer (if self_update.enabled)
```

---

## ✅ Step 6: Verify Services

### 6.1 Access Web Interfaces

```bash
# Get your server IP
hostname -I

# Access services:
# - Dockge: http://YOUR_IP:5001
# - Netdata: http://YOUR_IP:19999
# - Uptime Kuma: http://YOUR_IP:3001
```

### 6.2 Configure Uptime Kuma

1. Open Uptime Kuma: `http://YOUR_IP:3001`
2. Create admin account (use strong password!)
3. Add monitors:
   - Netdata: HTTP monitor on `http://localhost:19999/api/v1/info`
   - Dockge: HTTP monitor on `http://localhost:5001`
   - Docker: Docker monitor on `unix:///var/run/docker.sock`

### 6.3 Configure Netdata Alarms

Netdata alarms are pre-configured but you can customize:

```bash
# Edit Netdata config
docker exec -it netdata nano /etc/netdata/health.d/cpu.conf
docker restart netdata
```

### 6.4 Test Backup

```bash
# Run manual backup
ansible-playbook playbooks/backup.yml

# Verify backup
sudo restic -r /mnt/nas/backup/restic snapshots
```

### 6.5 Run Security Audit

```bash
# Run security scan
ansible-playbook playbooks/security.yml

# Check report
sudo cat /var/log/lynis/report.dat
```

---

## 🧹 Step 7: Clean Up Old System

### 7.1 Verify New System Works

Before removing old system, ensure:

- [ ] All services are running
- [ ] Backups are working
- [ ] Monitoring is functional
- [ ] Alerts are configured
- [ ] Custom stacks are migrated

### 7.2 Remove Old Bash System

```bash
# Stop old service (if not done already)
sudo systemctl stop server-helper
sudo systemctl disable server-helper
sudo rm /etc/systemd/system/server-helper.service
sudo systemctl daemon-reload

# Remove old installation
sudo rm -rf /opt/Server-Helper

# Keep backup of old config
# Don't delete ~/server-helper-v0.3.0.conf yet!
```

### 7.3 Clean Up Old Backups (Optional)

```bash
# Old tar backups can coexist with Restic
# If you want to remove them after verifying Restic works:

# List old backups
ls -lh /mnt/nas/dockge_backups/*.tar.gz

# Remove old backups (only after Restic is verified!)
# sudo rm /mnt/nas/dockge_backups/dockge_backup_*.tar.gz
```

---

## 🔄 Step 8: Ongoing Operations

### 8.1 Daily Operations

```bash
# Check service status
ansible-playbook playbooks/setup.yml --tags status

# Run manual backup
ansible-playbook playbooks/backup.yml

# Security audit
ansible-playbook playbooks/security.yml

# View logs
sudo journalctl -u restic-backup -f
```

### 8.2 Common Tasks

**Update configuration:**
```bash
cd /opt/Server-Helper-Ansible
sudo nano group_vars/all.yml
ansible-playbook playbooks/setup.yml
```

**Add new stack in Dockge:**
1. Go to Dockge UI: `http://YOUR_IP:5001`
2. Click "Compose" → "Create"
3. Add your docker-compose.yml

**Restore from backup:**
```bash
# List snapshots
sudo restic -r /mnt/nas/backup/restic snapshots

# Restore
sudo restic -r /mnt/nas/backup/restic restore <snapshot-id> --target /tmp/restore
```

---

## 🐛 Troubleshooting

### Problem: Ansible playbook fails

**Solution:**
```bash
# Run with verbose output
ansible-playbook playbooks/setup.yml -vvv

# Check for syntax errors
ansible-playbook playbooks/setup.yml --syntax-check

# Check connectivity
ansible all -m ping
```

### Problem: Services not starting

**Solution:**
```bash
# Check Docker
sudo systemctl status docker
docker ps -a

# Check specific container
docker logs <container-name>

# Restart stack via Dockge UI or:
cd /opt/dockge/stacks/<stack-name>
sudo docker-compose restart
```

### Problem: NAS won't mount

**Solution:**
```bash
# Check NAS connectivity
ping 192.168.1.100

# Try manual mount
sudo mount -t cifs //192.168.1.100/share /mnt/nas/backup -o username=user,password=pass

# Check credentials file
sudo cat /root/.nascreds_*

# Re-run NAS role
ansible-playbook playbooks/setup.yml --tags nas
```

### Problem: Backups failing

**Solution:**
```bash
# Check Restic repository
sudo restic -r /mnt/nas/backup/restic check

# View backup logs
sudo journalctl -u restic-backup -n 50

# Test backup manually
sudo restic -r /mnt/nas/backup/restic backup /opt/dockge --verbose
```

### Problem: Can't access web UIs

**Solution:**
```bash
# Check firewall
sudo ufw status

# Allow ports
sudo ufw allow 5001  # Dockge
sudo ufw allow 19999 # Netdata
sudo ufw allow 3001  # Uptime Kuma

# Check if services are listening
sudo netstat -tlnp | grep -E '(5001|19999|3001)'
```

---

## 📊 Feature Comparison

### What You Gain

✅ **Web UIs**: Dockge, Netdata, Uptime Kuma
✅ **Better Monitoring**: Real-time metrics with Netdata
✅ **Better Backups**: Encrypted, deduplicated with Restic
✅ **Better Security**: Automated Lynis audits
✅ **Flexibility**: Multiple backup destinations
✅ **Idempotency**: Safe to re-run playbooks
✅ **Community Support**: Ansible Galaxy roles

### What You Lose

❌ **CLI Menu**: No interactive menu (replaced with web UIs)
❌ **Manual Commands**: No more `./server_helper_setup.sh <command>`
❌ **Bash Familiarity**: Learning curve for Ansible/YAML

### Equivalent Operations

| v0.3.0 | v1.0.0 |
|--------|--------|
| `./server_helper_setup.sh setup` | `ansible-playbook playbooks/setup.yml` |
| `./server_helper_setup.sh backup` | `ansible-playbook playbooks/backup.yml` |
| `./server_helper_setup.sh security-audit` | `ansible-playbook playbooks/security.yml` |
| `./server_helper_setup.sh service-status` | Dockge UI or `docker ps` |
| `./server_helper_setup.sh logs` | Netdata UI or `docker logs` |
| `./server_helper_setup.sh menu` | Access web UIs |

---

## 📚 Additional Resources

- **Main README**: [README.md](README.md)
- **Configuration Reference**: [group_vars/all.example.yml](group_vars/all.example.yml)
- **Ansible Documentation**: https://docs.ansible.com/
- **Netdata Docs**: https://learn.netdata.cloud/
- **Uptime Kuma**: https://github.com/louislam/uptime-kuma
- **Restic Docs**: https://restic.readthedocs.io/

---

## ✅ Migration Checklist

Use this checklist to track your migration:

- [ ] Pre-Migration
  - [ ] Export current config
  - [ ] Backup Dockge stacks
  - [ ] Export Uptime Kuma data
  - [ ] Document current setup
- [ ] Preparation
  - [ ] Install Ansible
  - [ ] Clone new repository
  - [ ] Configure inventory
  - [ ] Map configuration to YAML
- [ ] Migration
  - [ ] Stop old system
  - [ ] Run Ansible setup
  - [ ] Verify services
  - [ ] Migrate custom stacks
  - [ ] Configure Uptime Kuma
  - [ ] Test backups
- [ ] Post-Migration
  - [ ] Verify all functionality
  - [ ] Clean up old system
  - [ ] Update documentation
  - [ ] Monitor for issues
- [ ] Ongoing
  - [ ] Regular security audits
  - [ ] Backup testing
  - [ ] Update Ansible playbooks

---

## 🆘 Getting Help

If you encounter issues:

1. Check this guide thoroughly
2. Review [README.md](README.md) for configuration details
3. Run playbooks with `-vvv` for detailed output
4. Check service logs: `docker logs <container>`
5. Open an issue: https://github.com/thelasttenno/Server-Helper/issues

---

**Migration complete! Welcome to Server Helper v1.0.0!** 🎉
