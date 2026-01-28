# Scripts Directory

Utility scripts for Server Helper management and operations.

---

## 📋 Inventory Management Scripts

Tools for managing your Ansible inventory and adding new servers.

### `add-server.sh` - Interactive Server Addition

Add new servers to your inventory with an interactive wizard that guides you through the process.

```bash
# Interactive mode (guided prompts)
./scripts/add-server.sh

# Batch mode (add multiple servers)
./scripts/add-server.sh --batch

# Show help
./scripts/add-server.sh --help
```

**Features:**

- ✅ **Interactive Wizard**: Guided prompts for all server details
- ✅ **Input Validation**: Validates IP addresses, hostnames, and ports
- ✅ **SSH Testing**: Tests connectivity before adding to inventory
- ✅ **Auto-Backup**: Backs up inventory before making changes
- ✅ **Group Management**: Automatically adds servers to groups
- ✅ **Batch Mode**: Add multiple servers in one session
- ✅ **Custom Options**: Supports custom SSH ports, keys, timezones

**What It Asks:**

- Server name (friendly identifier)
- IP address or hostname
- SSH username (default: ansible)
- SSH port (default: 22)
- Custom hostname (optional)
- SSH private key path (optional)
- Server group (default: servers)
- Timezone (optional)

**Example Session:**

```bash
$ ./scripts/add-server.sh

╔════════════════════════════════════════════════════════════════════╗
║                 Server Helper - Add Server Tool                    ║
╚════════════════════════════════════════════════════════════════════╝

ℹ This wizard will guide you through adding a new server to the inventory.

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
> production

Timezone (leave empty for default in group_vars/all.yml):
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

**Use Cases:**

✅ **Adding Your First Server**

```bash
./scripts/add-server.sh
# Follow prompts, script tests connection and adds to inventory
```

✅ **Adding Multiple Servers**

```bash
./scripts/add-server.sh --batch
# Add servers one after another in a single session
```

✅ **Adding Cloud Server with Custom Key**

```bash
./scripts/add-server.sh
# Specify custom SSH key path when prompted
# Example: ~/.ssh/aws_key.pem
```

✅ **Adding Server with Non-Standard SSH Port**

```bash
./scripts/add-server.sh
# Specify custom port when prompted (e.g., 2222)
```

**Safety Features:**

- Automatic inventory backup before changes
- Validates all inputs before adding
- Tests SSH connectivity (optional)
- Confirms before making changes
- Won't overwrite existing servers

---

## 🔐 Vault Management Scripts

Ansible Vault helper scripts for secure secrets management.

### Master Script: `vault.sh`

All-in-one tool for vault operations. This is the **recommended** way to manage vault files.

```bash
# Initialize vault setup
./scripts/vault.sh init

# Show vault status and health check
./scripts/vault.sh status

# Create new encrypted vault file
./scripts/vault.sh create group_vars/vault.yml

# Edit encrypted vault file (recommended - no plain text file created)
./scripts/vault.sh edit group_vars/vault.yml

# View encrypted vault file (read-only)
./scripts/vault.sh view group_vars/vault.yml

# Validate vault file(s)
./scripts/vault.sh validate
./scripts/vault.sh validate group_vars/vault.yml

# Backup vault file
./scripts/vault.sh backup group_vars/vault.yml

# Restore from backup
./scripts/vault.sh restore backups/vault/vault.yml.backup.20250101_120000

# Show diff of encrypted file
./scripts/vault.sh diff group_vars/vault.yml

# Change vault password
./scripts/vault.sh rekey group_vars/vault.yml
./scripts/vault.sh rekey --all  # Re-key all encrypted files

# Show help
./scripts/vault.sh help
```

### Individual Helper Scripts

These scripts are called by `vault.sh` but can also be used independently:

#### `vault-edit.sh` - Edit Encrypted Files (RECOMMENDED)

Safely edit vault files without creating plain text files.

```bash
./scripts/vault-edit.sh group_vars/vault.yml
```

**Use this for:**
- ✅ Adding new secrets
- ✅ Updating existing secrets
- ✅ Creating new encrypted files

**Security:** Decrypts in-memory only, never creates plain text files.

#### `vault-view.sh` - View Encrypted Files (SAFE)

View vault contents without editing.

```bash
./scripts/vault-view.sh group_vars/vault.yml
```

**Use this for:**
- ✅ Checking secret values
- ✅ Code review
- ✅ Debugging

**Security:** Read-only, no plain text files created.

#### `vault-encrypt.sh` - Encrypt Plain Text Files

Encrypt existing plain text files.

```bash
./scripts/vault-encrypt.sh group_vars/vault.yml
```

**Use this for:**
- Converting plain text to encrypted
- Initial vault setup
- Re-encrypting after manual edits

**Safety:** Creates backup before encrypting.

#### `vault-decrypt.sh` - Decrypt Encrypted Files (DANGEROUS)

⚠️ **WARNING:** Creates plain text files with sensitive data!

```bash
./scripts/vault-decrypt.sh group_vars/vault.yml
```

**Only use this when:**
- Absolutely necessary
- You understand the security risks
- You will re-encrypt immediately after

**Security:** Displays multiple warnings before proceeding.

#### `vault-rekey.sh` - Change Vault Password

Rotate vault passwords for security.

```bash
# Re-key single file
./scripts/vault-rekey.sh group_vars/vault.yml

# Re-key ALL encrypted files
./scripts/vault-rekey.sh --all
```

**Use this for:**
- ✅ Regular password rotation (security best practice)
- ✅ After team member offboarding
- ✅ If vault password compromised
- ✅ Periodic security updates

**Safety:** Creates backups before re-keying.

---

## 📋 Script Features

### Security Features

All vault scripts include:

- ✅ **Password file validation** - Checks `.vault_password` exists
- ✅ **File permission checks** - Ensures secure file permissions
- ✅ **Automatic backups** - Creates backups before destructive operations
- ✅ **Confirmation prompts** - Asks before dangerous operations
- ✅ **Colored output** - Clear visual feedback
- ✅ **Error handling** - Fails safely on errors
- ✅ **Cleanup** - Removes temporary files

### User Experience

- **Colored output**: Green ✓ success, Red ✗ errors, Yellow ⚠ warnings
- **Progress indicators**: Shows what's happening
- **Helpful messages**: Suggests next steps
- **Error recovery**: Guides you when things go wrong
- **Consistent interface**: All scripts work the same way

---

## 🚀 Common Workflows

### Initial Vault Setup

```bash
# 1. Initialize vault
./scripts/vault.sh init

# 2. Edit vault file to add secrets
./scripts/vault.sh edit group_vars/vault.yml

# 3. Verify vault works
./scripts/vault.sh validate

# 4. Check status
./scripts/vault.sh status
```

### Daily Usage

```bash
# View secrets
./scripts/vault.sh view group_vars/vault.yml

# Edit secrets
./scripts/vault.sh edit group_vars/vault.yml

# Check vault health
./scripts/vault.sh status
```

### Security Operations

```bash
# Rotate vault password (monthly recommended)
./scripts/vault.sh rekey --all

# Backup before major changes
./scripts/vault.sh backup group_vars/vault.yml

# Validate after changes
./scripts/vault.sh validate
```

### Team Collaboration

```bash
# Team lead: Initialize and share password securely
./scripts/vault.sh init
# Share .vault_password via password manager

# Team member: Verify access
./scripts/vault.sh validate

# Code review: View vault changes
./scripts/vault.sh diff group_vars/vault.yml
```

---

## 🎯 Best Practices

### DO's ✅

- ✅ Use `vault.sh` or `vault-edit.sh` for editing (safest)
- ✅ Use `vault-view.sh` for viewing (read-only)
- ✅ Run `vault.sh status` regularly
- ✅ Validate after changes: `vault.sh validate`
- ✅ Backup before major changes: `vault.sh backup`
- ✅ Rotate passwords periodically: `vault.sh rekey --all`
- ✅ Keep `.vault_password` file secure (chmod 600)
- ✅ Add `.vault_password` to `.gitignore`

### DON'Ts ❌

- ❌ Never use `vault-decrypt.sh` unless absolutely necessary
- ❌ Never commit `.vault_password` to Git
- ❌ Never commit decrypted vault files
- ❌ Never share vault password via email/chat
- ❌ Never skip validation after changes
- ❌ Never edit encrypted files with text editor directly

---

## 🐛 Troubleshooting

### "Vault password file not found"

```bash
# Initialize vault
./scripts/vault.sh init

# Or create manually
openssl rand -base64 32 > .vault_password
chmod 600 .vault_password
```

### "Decryption failed"

```bash
# Wrong password file
# Check you're using the correct password

# Verify password file exists
ls -la .vault_password

# Test with another vault file
./scripts/vault.sh validate
```

### "File is not encrypted"

```bash
# Encrypt the file
./scripts/vault-encrypt.sh group_vars/vault.yml

# Or create new encrypted file
./scripts/vault.sh create group_vars/vault.yml
```

### "Permission denied"

```bash
# Fix file permissions
chmod 600 .vault_password
chmod 644 group_vars/vault.yml

# Fix script permissions
chmod +x scripts/vault*.sh
```

---

## 📚 Additional Resources

### Documentation

- [docs/guides/vault.md](../docs/guides/vault.md) - Complete vault guide
- [docs/reference/vault-commands.md](../docs/reference/vault-commands.md) - Quick reference
- [docs/workflows/vault-in-ci-cd.md](../docs/workflows/vault-in-ci-cd.md) - CI/CD integration
- [docs/integrations/external-secrets.md](../docs/integrations/external-secrets.md) - External secret managers

### Ansible Vault Documentation

- Official docs: https://docs.ansible.com/ansible/latest/user_guide/vault.html
- Best practices: https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html#variables-and-vaults

---

## 🔧 Script Maintenance

### Script Dependencies

All scripts require:
- `bash` (tested with 4.0+)
- `ansible-vault` (comes with Ansible)
- `openssl` (for password generation)
- Standard Unix tools: `grep`, `find`, `chmod`, etc.

### Script Compatibility

- ✅ Linux (Ubuntu, Debian, RHEL, etc.)
- ✅ macOS
- ✅ WSL (Windows Subsystem for Linux)
- ❌ Native Windows (use WSL or Git Bash)

### Adding Custom Scripts

To add your own vault management scripts:

1. Follow the naming convention: `vault-<action>.sh`
2. Include security checks and validations
3. Use colored output for consistency
4. Add error handling
5. Document in this README
6. Consider adding to `vault.sh` as a command

---

## 📝 Script Help

Each script has built-in help:

```bash
./scripts/vault.sh help
./scripts/vault-edit.sh
./scripts/vault-view.sh
./scripts/vault-encrypt.sh
./scripts/vault-decrypt.sh
./scripts/vault-rekey.sh
```

---

**Remember: Security is only as strong as your weakest link. Use these tools wisely!** 🔐
