# Ansible Vault Guide - Secure Secrets Management

This guide explains how to use Ansible Vault to encrypt sensitive data in Server Helper v1.0.0.

---

## 🔐 What is Ansible Vault?

Ansible Vault encrypts sensitive data (passwords, API keys, certificates) so you can safely commit them to Git. Only those with the vault password can decrypt and use the secrets.

**Benefits:**
- ✅ Store secrets in Git safely
- ✅ Version control for sensitive data
- ✅ Team collaboration without exposing secrets
- ✅ Automated decryption during playbook runs

---

## 📁 Vault File Structure

Server Helper uses a **split configuration** approach:

```
group_vars/
├── all.yml              # Non-sensitive configuration (safe to commit)
└── vault.yml            # Encrypted secrets (safe to commit when encrypted)
```

**all.yml** contains:
- System settings (hostname, timezone)
- Service ports
- Feature flags
- Non-sensitive paths

**vault.yml** contains:
- Passwords
- API keys
- Credentials
- Certificates
- Any sensitive data

---

## 🚀 Quick Start

### 1. Create Vault Password File

```bash
# Create a strong password file (DON'T commit this!)
openssl rand -base64 32 > .vault_password

# Secure it
chmod 600 .vault_password
```

### 2. Configure Ansible to Use Vault Password

```bash
# Option A: Add to ansible.cfg (already configured)
cat ansible.cfg | grep vault_password_file
# Output: vault_password_file = .vault_password

# Option B: Environment variable
export ANSIBLE_VAULT_PASSWORD_FILE=.vault_password

# Option C: Command line flag (for one-time use)
ansible-playbook playbooks/setup.yml --vault-password-file=.vault_password
```

### 3. Create Encrypted Vault File

```bash
# Create new encrypted file
ansible-vault create group_vars/vault.yml

# You'll enter your editor to add secrets
```

### 4. Edit Vault File

```bash
# Edit encrypted file
ansible-vault edit group_vars/vault.yml

# View encrypted file (without editing)
ansible-vault view group_vars/vault.yml
```

---

## 📝 Vault File Template

### Example: `group_vars/vault.yml`

```yaml
---
# Ansible Vault - Encrypted Secrets
# Edit with: ansible-vault edit group_vars/vault.yml

# =============================================================================
# NAS CREDENTIALS
# =============================================================================

vault_nas_credentials:
  - username: "nasuser"
    password: "SuperSecretNASPassword123!"
  # Add more NAS credentials as needed

# =============================================================================
# BACKUP PASSWORDS
# =============================================================================

# Restic repository passwords
vault_restic_passwords:
  nas: "ResticNASRepoPassword456!"
  s3: "ResticS3RepoPassword789!"
  b2: "ResticB2RepoPassword012!"
  local: "ResticLocalRepoPassword345!"

# =============================================================================
# CLOUD CREDENTIALS
# =============================================================================

# AWS S3 credentials
vault_aws_credentials:
  access_key: "AKIAIOSFODNN7EXAMPLE"
  secret_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Backblaze B2 credentials
vault_b2_credentials:
  account_id: "0123456789abcdef0123456789abcdef01234567"
  account_key: "K001abcdefghijklmnopqrstuvwxyz1234567890"

# =============================================================================
# SERVICE CREDENTIALS
# =============================================================================

# Dockge admin credentials
vault_dockge_credentials:
  username: "admin"
  password: "DockgeAdminPassword678!"

# Uptime Kuma admin credentials
vault_uptime_kuma_credentials:
  username: "admin"
  password: "UptimeKumaPassword901!"

# Netdata Cloud claim token (optional)
vault_netdata_claim_token: "xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# =============================================================================
# NOTIFICATION CREDENTIALS
# =============================================================================

# Email (SMTP)
vault_smtp_credentials:
  host: "smtp.gmail.com"
  port: 587
  username: "your-email@gmail.com"
  password: "YourAppPassword234!"

# Discord webhook
vault_discord_webhook: "https://discord.com/api/webhooks/123456789/abcdefghijklmnopqrstuvwxyz"

# Telegram
vault_telegram_credentials:
  bot_token: "123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
  chat_id: "-1001234567890"

# =============================================================================
# UPTIME KUMA PUSH URLS
# =============================================================================

vault_uptime_kuma_push_urls:
  nas: "http://localhost:3001/api/push/ABC123XYZ?status=up&msg=OK"
  dockge: "http://localhost:3001/api/push/DEF456XYZ?status=up&msg=OK"
  system: "http://localhost:3001/api/push/GHI789XYZ?status=up&msg=OK"
  backup: "http://localhost:3001/api/push/JKL012XYZ?status=up&msg=OK"
  security: "http://localhost:3001/api/push/MNO345XYZ?status=up&msg=OK"
  update: "http://localhost:3001/api/push/PQR678XYZ?status=up&msg=OK"

# =============================================================================
# SSL CERTIFICATES (if using custom certs)
# =============================================================================

vault_ssl_certificate: |
  -----BEGIN CERTIFICATE-----
  MIIDXTCCAkWgAwIBAgIJAKL0UG+mRKuoMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
  [... certificate content ...]
  -----END CERTIFICATE-----

vault_ssl_private_key: |
  -----BEGIN PRIVATE KEY-----
  MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7VJTUt9Us8cKj
  [... private key content ...]
  -----END PRIVATE KEY-----
```

---

## 🔗 Reference Vault Variables in all.yml

### Example: `group_vars/all.yml`

```yaml
---
# Server Helper Configuration - Non-Sensitive Settings

# =============================================================================
# NAS CONFIGURATION
# =============================================================================

nas:
  enabled: true
  shares:
    - ip: "192.168.1.100"
      share: "backup"
      mount: "/mnt/nas/backup"
      # Reference vault variables
      username: "{{ vault_nas_credentials[0].username }}"
      password: "{{ vault_nas_credentials[0].password }}"
      options: "vers=3.0,_netdev,nofail"

# =============================================================================
# BACKUP CONFIGURATION
# =============================================================================

restic:
  enabled: true
  schedule: "0 2 * * *"
  
  destinations:
    nas:
      enabled: true
      path: "/mnt/nas/backup/restic"
      # Reference vault variable
      password: "{{ vault_restic_passwords.nas }}"
    
    s3:
      enabled: false
      bucket: "my-server-backups"
      endpoint: "s3.amazonaws.com"
      region: "us-east-1"
      # Reference vault variables
      access_key: "{{ vault_aws_credentials.access_key }}"
      secret_key: "{{ vault_aws_credentials.secret_key }}"
      password: "{{ vault_restic_passwords.s3 }}"
    
    b2:
      enabled: false
      bucket: "my-server-backups"
      # Reference vault variables
      account_id: "{{ vault_b2_credentials.account_id }}"
      account_key: "{{ vault_b2_credentials.account_key }}"
      password: "{{ vault_restic_passwords.b2 }}"
  
  # Uptime Kuma heartbeat URL (from vault)
  uptime_kuma_push_url: "{{ vault_uptime_kuma_push_urls.backup }}"

# =============================================================================
# MONITORING
# =============================================================================

netdata:
  enabled: true
  port: 19999
  # Netdata Cloud claim token (from vault)
  claim_token: "{{ vault_netdata_claim_token | default('') }}"
  
  alarms:
    enabled: true
    cpu_warning: 80
    cpu_critical: 95
    uptime_kuma_urls:
      cpu: "{{ vault_uptime_kuma_push_urls.system }}"

uptime_kuma:
  enabled: true
  port: 3001
  # Admin credentials (from vault)
  admin_username: "{{ vault_uptime_kuma_credentials.username }}"
  admin_password: "{{ vault_uptime_kuma_credentials.password }}"

dockge:
  enabled: true
  port: 5001
  # Admin credentials (from vault)
  admin_username: "{{ vault_dockge_credentials.username }}"
  admin_password: "{{ vault_dockge_credentials.password }}"

# =============================================================================
# NOTIFICATIONS
# =============================================================================

notifications:
  email:
    enabled: false
    # SMTP credentials (from vault)
    smtp_host: "{{ vault_smtp_credentials.host }}"
    smtp_port: "{{ vault_smtp_credentials.port }}"
    smtp_username: "{{ vault_smtp_credentials.username }}"
    smtp_password: "{{ vault_smtp_credentials.password }}"
  
  discord:
    enabled: false
    # Webhook URL (from vault)
    webhook_url: "{{ vault_discord_webhook }}"
  
  telegram:
    enabled: false
    # Bot credentials (from vault)
    bot_token: "{{ vault_telegram_credentials.bot_token }}"
    chat_id: "{{ vault_telegram_credentials.chat_id }}"
```

---

## 🛠️ Common Vault Commands

### Create and Edit

```bash
# Create new encrypted file
ansible-vault create group_vars/vault.yml

# Edit existing encrypted file
ansible-vault edit group_vars/vault.yml

# View encrypted file (read-only)
ansible-vault view group_vars/vault.yml
```

### Encryption Operations

```bash
# Encrypt existing plain text file
ansible-vault encrypt group_vars/vault.yml

# Decrypt file (be careful!)
ansible-vault decrypt group_vars/vault.yml

# Change vault password
ansible-vault rekey group_vars/vault.yml
```

### Using with Playbooks

```bash
# Run playbook (uses vault password file from ansible.cfg)
ansible-playbook playbooks/setup.yml

# Run with password prompt
ansible-playbook playbooks/setup.yml --ask-vault-pass

# Run with specific password file
ansible-playbook playbooks/setup.yml --vault-password-file=/path/to/password

# Run with multiple vault passwords (if using multiple vaults)
ansible-playbook playbooks/setup.yml --vault-id dev@.vault_password_dev --vault-id prod@.vault_password_prod
```

---

## 🔄 Workflow Examples

### Initial Setup

```bash
# 1. Create vault password
openssl rand -base64 32 > .vault_password
chmod 600 .vault_password

# 2. Create vault file
ansible-vault create group_vars/vault.yml
# (Add your secrets in the editor)

# 3. Create main config file
cp group_vars/all.example.yml group_vars/all.yml
nano group_vars/all.yml
# (Reference vault variables with {{ vault_xxx }})

# 4. Run setup
ansible-playbook playbooks/setup.yml
```

### Updating Secrets

```bash
# Edit vault
ansible-vault edit group_vars/vault.yml

# Re-run playbook to apply changes
ansible-playbook playbooks/setup.yml
```

### Team Collaboration

```bash
# Share vault password securely (NOT via email/slack!)
# Use: Password manager, encrypted chat, or in-person

# Team member setup
git clone https://github.com/your-org/Server-Helper.git
cd Server-Helper

# Create vault password file (from secure source)
echo "shared-vault-password" > .vault_password
chmod 600 .vault_password

# Now can run playbooks
ansible-playbook playbooks/setup.yml
```

---

## 🔒 Security Best Practices

### DO's ✅

- ✅ **Use strong vault passwords**: 32+ characters, random
- ✅ **Secure password file**: `chmod 600 .vault_password`
- ✅ **Add to .gitignore**: Never commit `.vault_password`
- ✅ **Commit encrypted vault.yml**: Safe when encrypted
- ✅ **Use separate vaults**: For dev/staging/prod
- ✅ **Rotate passwords**: Change vault password periodically
- ✅ **Share securely**: Use password managers or encrypted channels
- ✅ **Backup vault password**: Store in password manager

### DON'Ts ❌

- ❌ **Never commit plain text secrets**: Always encrypt first
- ❌ **Never commit .vault_password**: Add to .gitignore
- ❌ **Never share vault password via**: Email, Slack, SMS, etc.
- ❌ **Never decrypt and commit**: Keep vault.yml encrypted
- ❌ **Never use weak passwords**: "password123" is not acceptable
- ❌ **Never leave decrypted files**: Delete them after use
- ❌ **Never store in public repos**: Even encrypted (if very sensitive)

---

## 🎯 Multiple Environments

For dev/staging/production, use vault IDs:

### Structure

```
group_vars/
├── all/
│   ├── main.yml          # Common non-sensitive settings
│   └── vault.yml         # Common encrypted secrets
├── dev/
│   ├── main.yml          # Dev-specific settings
│   └── vault.yml         # Dev-specific secrets
├── staging/
│   ├── main.yml          # Staging-specific settings
│   └── vault.yml         # Staging-specific secrets
└── prod/
    ├── main.yml          # Prod-specific settings
    └── vault.yml         # Prod-specific secrets
```

### Usage

```bash
# Create vault with ID
ansible-vault create --vault-id dev@.vault_password_dev group_vars/dev/vault.yml
ansible-vault create --vault-id prod@.vault_password_prod group_vars/prod/vault.yml

# Run with specific vault
ansible-playbook playbooks/setup.yml --vault-id dev@.vault_password_dev
ansible-playbook playbooks/setup.yml --vault-id prod@.vault_password_prod
```

---

## 🧪 Testing Vault Configuration

### Verify Vault is Encrypted

```bash
# Try to view encrypted file (should show encrypted data)
cat group_vars/vault.yml
# Output: $ANSIBLE_VAULT;1.1;AES256...

# Verify can decrypt with password
ansible-vault view group_vars/vault.yml
# Should show plain text
```

### Test Variable Reference

```bash
# Check if variables are accessible
ansible all -m debug -a "var=vault_nas_credentials[0].username" --limit localhost

# Run playbook in check mode
ansible-playbook playbooks/setup.yml --check
```

---

## 🚨 Troubleshooting

### Error: "Decryption failed"

```bash
# Check password file exists
ls -la .vault_password

# Verify password is correct
ansible-vault view group_vars/vault.yml --vault-password-file=.vault_password

# Check ansible.cfg points to correct file
grep vault_password_file ansible.cfg
```

### Error: "Variable not found"

```bash
# Check variable name in vault.yml
ansible-vault view group_vars/vault.yml | grep vault_nas_credentials

# Check reference in all.yml
grep vault_nas_credentials group_vars/all.yml
```

### Error: "Could not find vault password"

```bash
# Set environment variable
export ANSIBLE_VAULT_PASSWORD_FILE=.vault_password

# Or use command line
ansible-playbook playbooks/setup.yml --vault-password-file=.vault_password
```

---

## 📋 Checklist for Vault Setup

- [ ] Create `.vault_password` file with strong password
- [ ] Set permissions: `chmod 600 .vault_password`
- [ ] Add `.vault_password` to `.gitignore`
- [ ] Create `group_vars/vault.yml` with secrets
- [ ] Update `group_vars/all.yml` to reference vault variables
- [ ] Configure `ansible.cfg` with vault password file path
- [ ] Test decryption: `ansible-vault view group_vars/vault.yml`
- [ ] Run playbook to verify: `ansible-playbook playbooks/setup.yml --check`
- [ ] Commit encrypted `vault.yml` to Git
- [ ] Share vault password securely with team
- [ ] Document where vault password is stored

---

## 🔑 Password Management

### Where to Store Vault Password

**Options (from most to least secure):**

1. **Hardware Token**: YubiKey, Nitrokey
2. **Password Manager**: 1Password, Bitwarden, LastPass
3. **Encrypted File**: On encrypted disk/USB
4. **Paper**: In safe/lockbox (physical backup)
5. **Environment Variable**: For CI/CD (ephemeral)

**Never:**
- ❌ Plain text file in home directory
- ❌ Committed to Git
- ❌ Sent via email/chat
- ❌ Written on sticky note

---

## 📚 Additional Resources

- **Ansible Vault Docs**: https://docs.ansible.com/ansible/latest/user_guide/vault.html
- **Vault Best Practices**: https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html#variables-and-vaults
- **Managing Secrets**: https://www.ansible.com/blog/managing-secrets-with-ansible-vault

---

**Remember: Security is only as strong as your weakest link. Protect your vault password!** 🔐
