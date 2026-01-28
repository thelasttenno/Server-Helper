# Server Helper v1.0.0 - New Features Added

This document describes the new features added to Server Helper v1.0.0.

## Summary

The following features have been integrated into both the Ansible playbooks and the bash setup script:

1. ✅ **User Account Management** - Create admin users, configure sudo, disable root
2. ✅ **SSH Server Installation & Configuration** - Install OpenSSH, configure hardening
3. ✅ **Key-based Authentication** - Add SSH public keys for passwordless login
4. ✅ **Hostname Management** - Set or change system hostname
5. ✅ **Timezone Configuration** - Set system timezone
6. ✅ **QEMU Guest Agent** - For Proxmox/KVM virtualization
7. ✅ **LVM Configuration** - Fix Ubuntu default partitioning, extend volumes

---

## 1. User Account Management

### Features
- Create new admin user with custom username and password
- Configure sudo access (passwordless or with password)
- Add user to docker and sudo groups
- Disable root password login for security
- Support for additional users

### Ansible Role: `system_users`

**Location:** `roles/system_users/`

**Configuration in `group_vars/all.yml`:**
```yaml
system_users:
  create_admin_user: true
  admin_user: "admin"
  admin_password: "{{ vault_system_users.admin_password }}"
  admin_groups:
    - sudo
    - docker
  admin_passwordless_sudo: true
  admin_ssh_key: "{{ vault_system_users.admin_ssh_key }}"
  disable_root_password: true
  additional_users: []
```

**What it does:**
- Creates admin user account
- Sets up sudo permissions in `/etc/sudoers.d/`
- Locks root account password
- Validates sudoers configuration before applying

**Setup Script Prompts:**
```
Create new admin user account? (y/N):
Admin username [admin]:
Admin password: ********
Enable passwordless sudo for admin? (Y/n):
Add SSH public key for admin? (Y/n):
Disable root password login? (Y/n):
```

---

## 2. SSH Server Installation & Configuration

### Features
- Installs OpenSSH server if not present
- Comprehensive SSH hardening with modern ciphers
- Configurable SSH port
- Disable password authentication (key-based only)
- Disable root login
- Strong cipher suites and key exchange algorithms
- Automatic UFW firewall rule for SSH port

### Enhanced Role: `security` (ssh.yml)

**Location:** `roles/security/tasks/ssh.yml`

**Configuration in `group_vars/all.yml`:**
```yaml
security:
  ssh_install_server: true
  ssh_port: 22
  ssh_password_authentication: false
  ssh_permit_root_login: false
  ssh_max_auth_tries: 3
  ssh_client_alive_interval: 300
```

**SSH Hardening Applied:**
- Protocol 2 only
- Strong ciphers: `chacha20-poly1305@openssh.com`, `aes256-gcm@openssh.com`, etc.
- Strong MACs: `hmac-sha2-512-etm@openssh.com`, `hmac-sha2-256-etm@openssh.com`
- Strong key exchange: `curve25519-sha256`, `diffie-hellman-group16-sha512`
- X11 forwarding disabled
- Empty passwords disabled
- Host-based authentication disabled

**Setup Script Prompts:**
```
Enable SSH hardening? (Y/n):
SSH port [22]:
Disable SSH password authentication? (Y/n):
Disable SSH root login? (Y/n):
```

---

## 3. Key-based Authentication

### Features
- Add SSH public keys during user creation
- Automatic `.ssh` directory setup with correct permissions
- Support for multiple users with different keys
- Stores keys securely in Ansible Vault

### Implementation

**Vault Configuration (`group_vars/vault.yml`):**
```yaml
vault_system_users:
  admin_password: "strong-password"
  admin_ssh_key: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... user@host"
```

**What it does:**
- Creates `/home/user/.ssh` with mode 0700
- Adds public key to `~/.ssh/authorized_keys`
- Sets proper ownership and permissions

**Setup Script Prompts:**
```
Add SSH public key for admin? (Y/n):
Enter SSH public key (paste full key):
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC...
```

---

## 4. Hostname Management

### Features
- Set custom hostname during setup
- Updates `/etc/hosts` automatically
- Applies immediately without reboot

### Implementation

**Already in `common` role:** `roles/common/tasks/main.yml`

**Configuration:**
```yaml
hostname: "server-01"
```

**Setup Script Prompts:**
```
Server hostname [server-01]:
```

---

## 5. Timezone Configuration

### Features
- Set system timezone
- Supports all standard timezones
- Applies immediately

### Implementation

**Already in `common` role:** `roles/common/tasks/main.yml`

**Configuration:**
```yaml
timezone: "America/New_York"
```

**Setup Script Prompts:**
```
Timezone [America/New_York]:
```

**List available timezones:**
```bash
timedatectl list-timezones
```

---

## 6. QEMU Guest Agent for Proxmox

### Features
- Installs QEMU guest agent for VM integration
- Enables better Proxmox/KVM integration
- Provides VM information to hypervisor
- Enables features like graceful shutdown, IP address reporting, etc.

### Implementation

**Added to `common` role:** `roles/common/tasks/main.yml`

**Configuration:**
```yaml
virtualization:
  qemu_guest_agent: true
```

**What it does:**
- Installs `qemu-guest-agent` package
- Enables and starts the service
- Detects virtualization platform using `systemd-detect-virt`

**Setup Script Prompts:**
```
Install QEMU guest agent (for Proxmox/KVM)? (y/N):
```

**Verify installation:**
```bash
# Check service status
systemctl status qemu-guest-agent

# Detect virtualization platform
systemd-detect-virt
```

---

## 7. LVM Configuration & Ubuntu Partitioning Fix

### Features
- Automatically extends Ubuntu default LVM to use all available space
- Custom logical volume extension
- Create new logical volumes
- Resize filesystems automatically
- Support for ext4, xfs, and other filesystems

### New Role: `lvm_config`

**Location:** `roles/lvm_config/`

**Configuration:**
```yaml
lvm_config:
  enabled: true
  auto_extend_ubuntu: true  # Fix Ubuntu default small partition

  # Extend custom volumes
  custom_lvs:
    - lv_path: "/dev/my-vg/my-lv"
      extend_percent: 100
      resize_cmd: "resize2fs"

  # Create new volumes
  create_lvs:
    - vg: "ubuntu-vg"
      lv: "docker-lv"
      size: "50G"
      fstype: "ext4"
      mount_point: "/var/lib/docker"
      mount_opts: "defaults,noatime"
```

**What it does:**
- Detects existing volume groups
- Extends logical volumes to use free space
- Resizes filesystems after extending
- Creates and mounts new logical volumes
- Displays disk usage summary

**Common Use Case - Fix Ubuntu Default:**
Ubuntu 24.04 installer often leaves most disk space unallocated. This role automatically extends the root LV:

```bash
# Before
/dev/ubuntu-vg/ubuntu-lv    10G  (100GB disk, 90GB unused!)

# After
/dev/ubuntu-vg/ubuntu-lv   100G  (all space used)
```

**Setup Script Prompts:**
```
Fix Ubuntu default LVM partitioning? (Y/n):
This will extend the root logical volume to use all available space.
```

**Manual Operations:**
```bash
# Check volume groups
vgs

# Check logical volumes
lvs

# Check disk usage
df -h

# Manually extend (if needed)
lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
resize2fs /dev/ubuntu-vg/ubuntu-lv
```

---

## File Changes Summary

### New Files Created

1. **`roles/system_users/tasks/main.yml`** - User management role
2. **`roles/system_users/defaults/main.yml`** - User management defaults
3. **`roles/lvm_config/tasks/main.yml`** - LVM configuration role
4. **`roles/lvm_config/defaults/main.yml`** - LVM configuration defaults

### Modified Files

1. **`roles/common/tasks/main.yml`** - Added QEMU guest agent installation
2. **`roles/security/tasks/ssh.yml`** - Enhanced SSH configuration with installation and hardening
3. **`playbooks/setup.yml`** - Added new roles to playbook execution order
4. **`group_vars/all.example.yml`** - Added configuration for all new features
5. **`group_vars/vault.example.yml`** - Added vault variables for user credentials
6. **`setup.sh`** - Added interactive prompts for all new features

---

## Execution Order in Playbook

The roles are executed in this order (from `playbooks/setup.yml`):

```yaml
roles:
  1. common              # Base system, hostname, timezone, QEMU agent
  2. lvm_config          # Fix partitioning (if enabled)
  3. system_users        # Create users, configure sudo (if enabled)
  4. system_setup        # Docker installation
  5. nas_mounts          # NAS shares (if enabled)
  6. security            # SSH hardening, fail2ban, UFW
  7. dockge              # Container management
  8. monitoring          # Netdata, Uptime Kuma
  9. backups             # Restic backups
  10. proxy              # Reverse proxy (if enabled)
```

This order ensures:
- LVM is configured before creating volumes for Docker
- Users are created before SSH hardening (to ensure access)
- SSH port is allowed in UFW before enabling firewall
- System is secured before installing services

---

## Security Considerations

### User Account Security
- ✅ Admin passwords stored encrypted in Ansible Vault
- ✅ Root password is locked (no password login)
- ✅ Sudoers configuration validated before applying
- ✅ SSH key authentication preferred over passwords

### SSH Security
- ✅ Strong ciphers and key exchange algorithms only
- ✅ Password authentication can be disabled
- ✅ Root login can be disabled
- ✅ SSH port automatically allowed in UFW
- ✅ Protocol 2 only (SSH-1 disabled)
- ✅ Client alive interval prevents connection hanging

### Important Warnings

**Before disabling SSH password authentication:**
1. Ensure SSH key is working: `ssh -i ~/.ssh/id_rsa user@server`
2. Keep a console/VNC session open as backup
3. Test sudo access: `sudo -v`

**Before locking root account:**
1. Ensure admin user has sudo access
2. Test: `sudo su -`
3. Keep console access available

---

## Testing the Setup

### Test User Creation
```bash
# SSH as new admin user
ssh admin@server

# Test sudo access
sudo -v

# Check groups
groups
# Should show: admin sudo docker

# Test docker group
docker ps
```

### Test SSH Configuration
```bash
# Check SSH service
systemctl status ssh

# View SSH config
sudo cat /etc/ssh/sshd_config | grep -E '^(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)'

# Test SSH key authentication
ssh -i ~/.ssh/id_rsa admin@server
```

### Test QEMU Guest Agent
```bash
# Check service
systemctl status qemu-guest-agent

# Check virtualization platform
systemd-detect-virt
# Output: kvm, qemu, vmware, or none

# From Proxmox host (if applicable)
qm agent <vmid> ping
```

### Test LVM Configuration
```bash
# Check volume groups
vgs

# Check logical volumes
lvs

# Check filesystem usage
df -h

# View LVM layout
lsblk
```

---

## Troubleshooting

### Locked Out of SSH

**Problem:** Disabled password auth but key doesn't work

**Solution:**
```bash
# Use console/VNC access
sudo nano /etc/ssh/sshd_config
# Change: PasswordAuthentication yes
sudo systemctl restart ssh
```

### Root Account Locked

**Problem:** Root password locked and admin user can't sudo

**Solution:**
```bash
# Boot into recovery mode or use console
# Unlock root temporarily
sudo passwd -u root
# Fix sudo for admin user
sudo usermod -aG sudo admin
```

### LVM Extension Failed

**Problem:** `lvextend` reports no free space

**Solution:**
```bash
# Check free space in VG
sudo vgs
sudo pvs

# Check if disk is fully allocated
sudo fdisk -l

# May need to extend physical volume first
sudo pvresize /dev/sda3
```

### QEMU Agent Not Working

**Problem:** Proxmox can't communicate with guest

**Solution:**
```bash
# Check service
sudo systemctl status qemu-guest-agent

# Restart service
sudo systemctl restart qemu-guest-agent

# Check logs
sudo journalctl -u qemu-guest-agent -f

# Ensure serial port is enabled in Proxmox VM config
```

---

## Examples

### Example 1: Secure Server Setup

```yaml
# group_vars/all.yml
system_users:
  create_admin_user: true
  admin_user: "sysadmin"
  admin_passwordless_sudo: true
  disable_root_password: true

security:
  ssh_port: 2222
  ssh_password_authentication: false
  ssh_permit_root_login: false

lvm_config:
  enabled: true
  auto_extend_ubuntu: true

virtualization:
  qemu_guest_agent: true  # If on Proxmox
```

### Example 2: Development Server

```yaml
# group_vars/all.yml
system_users:
  create_admin_user: true
  admin_user: "developer"
  admin_passwordless_sudo: true
  additional_users:
    - name: "tester"
      password: "{{ vault_system_users.tester_password }}"
      groups: ["docker"]
      ssh_key: "ssh-rsa AAAA..."

lvm_config:
  enabled: true
  create_lvs:
    - vg: "ubuntu-vg"
      lv: "projects-lv"
      size: "100G"
      fstype: "ext4"
      mount_point: "/home/developer/projects"
```

### Example 3: Proxmox VM Template

Perfect for creating a Proxmox VM template:

```yaml
# group_vars/all.yml
system_users:
  create_admin_user: true
  admin_user: "admin"
  admin_ssh_key: "{{ vault_system_users.admin_ssh_key }}"
  disable_root_password: true

security:
  ssh_password_authentication: false
  ssh_permit_root_login: false

lvm_config:
  enabled: true
  auto_extend_ubuntu: true

virtualization:
  qemu_guest_agent: true
```

This creates a secure, cloud-init ready VM template.

---

## Changelog

### Added
- User account creation and management role
- SSH server installation and comprehensive hardening
- SSH public key authentication support
- QEMU guest agent installation for Proxmox/KVM
- LVM configuration role to fix Ubuntu partitioning
- Interactive prompts in setup.sh for all new features
- Vault variables for secure credential storage

### Modified
- Enhanced SSH security with modern ciphers
- Automatic UFW rule for SSH port
- Improved setup.sh with additional configuration sections
- Updated playbook execution order

### Security Improvements
- Root password locking capability
- SSH key-based authentication
- Enhanced SSH cipher configuration
- Sudoers validation before applying
- Vault-encrypted credential storage

---

## Documentation

**Main README:** [README.md](README.md)
**Setup Script Guide:** [SETUP_SCRIPT_README.md](SETUP_SCRIPT_README.md)
**Vault Guide:** [VAULT_GUIDE.md](VAULT_GUIDE.md)
**Migration Guide:** [MIGRATION.md](MIGRATION.md)

---

**Server Helper v1.0.0** - Complete server automation with enhanced security and flexibility!
