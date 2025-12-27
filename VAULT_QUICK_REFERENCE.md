# Ansible Vault - Quick Reference Card

## 🔐 Setup (One-Time)

```bash
# Create vault password file
openssl rand -base64 32 > .vault_password
chmod 600 .vault_password

# Configure Ansible (add to ansible.cfg)
vault_password_file = .vault_password

# Or use environment variable
export ANSIBLE_VAULT_PASSWORD_FILE=.vault_password
```

---

## 📝 Create & Edit Vault Files

```bash
# Create new encrypted file
ansible-vault create group_vars/vault.yml

# Edit existing encrypted file
ansible-vault edit group_vars/vault.yml

# View encrypted file (read-only)
ansible-vault view group_vars/vault.yml
```

---

## 🔒 Encrypt & Decrypt

```bash
# Encrypt existing plain text file
ansible-vault encrypt group_vars/vault.yml

# Decrypt file (BE CAREFUL!)
ansible-vault decrypt group_vars/vault.yml

# Change vault password
ansible-vault rekey group_vars/vault.yml

# Encrypt string (for single variables)
ansible-vault encrypt_string 'my-secret-password' --name 'vault_nas_password'
```

---

## ▶️ Run Playbooks with Vault

```bash
# Use vault password file from ansible.cfg
ansible-playbook playbooks/setup.yml

# Prompt for vault password
ansible-playbook playbooks/setup.yml --ask-vault-pass

# Use specific password file
ansible-playbook playbooks/setup.yml --vault-password-file=.vault_password

# Multiple vaults (dev/prod)
ansible-playbook playbooks/setup.yml \
  --vault-id dev@.vault_password_dev \
  --vault-id prod@.vault_password_prod
```

---

## 🔍 Verify & Test

```bash
# Check if file is encrypted
head -1 group_vars/vault.yml
# Should show: $ANSIBLE_VAULT;1.1;AES256

# Test decryption
ansible-vault view group_vars/vault.yml --vault-password-file=.vault_password

# Check variable access
ansible all -m debug -a "var=vault_nas_credentials" --limit localhost

# Dry run playbook
ansible-playbook playbooks/setup.yml --check
```

---

## 📋 Common Patterns

### Reference Vault Variables

```yaml
# group_vars/all.yml
nas:
  username: "{{ vault_nas_credentials[0].username }}"
  password: "{{ vault_nas_credentials[0].password }}"

restic:
  destinations:
    nas:
      password: "{{ vault_restic_passwords.nas }}"
```

### Environment Variable Method

```bash
# Set password file location
export ANSIBLE_VAULT_PASSWORD_FILE=.vault_password

# Now run playbooks without --vault-password-file
ansible-playbook playbooks/setup.yml
```

### Vault ID Method (Multiple Environments)

```bash
# Create separate vault for each environment
ansible-vault create --vault-id dev@.vault_dev group_vars/dev/vault.yml
ansible-vault create --vault-id prod@.vault_prod group_vars/prod/vault.yml

# Run with specific environment
ansible-playbook playbooks/setup.yml --vault-id dev@.vault_dev
ansible-playbook playbooks/setup.yml --vault-id prod@.vault_prod
```

---

## ⚠️ Security Warnings

### ❌ NEVER DO THIS

```bash
# Never commit vault password
git add .vault_password  # ❌ DON'T!

# Never decrypt and commit
ansible-vault decrypt group_vars/vault.yml
git add group_vars/vault.yml  # ❌ DON'T!

# Never share password via insecure channels
echo "password123" | mail admin@example.com  # ❌ DON'T!
```

### ✅ ALWAYS DO THIS

```bash
# Add vault password to .gitignore
echo ".vault_password" >> .gitignore

# Use strong passwords
openssl rand -base64 32 > .vault_password

# Commit encrypted vault (safe!)
ansible-vault create group_vars/vault.yml
git add group_vars/vault.yml  # ✅ OK when encrypted

# Share password securely
# Use: Password manager, encrypted chat, or in-person
```

---

## 🚨 Emergency Procedures

### Lost Vault Password

```bash
# If you lose vault password, you CANNOT decrypt
# No recovery possible - you must recreate vault

# Create new vault with new password
ansible-vault create group_vars/vault_new.yml

# Re-enter all secrets manually
ansible-vault edit group_vars/vault_new.yml

# Replace old vault
mv group_vars/vault_new.yml group_vars/vault.yml
```

### Compromised Vault Password

```bash
# 1. Change vault password immediately
ansible-vault rekey group_vars/vault.yml

# 2. Change all secrets in vault
ansible-vault edit group_vars/vault.yml
# Update all passwords, API keys, etc.

# 3. Rotate all service passwords
# Change passwords in:
# - NAS
# - Cloud providers (AWS, B2)
# - Services (Dockge, Uptime Kuma)
# - Notification services (SMTP, Discord, etc.)

# 4. Update vault with new secrets
ansible-vault edit group_vars/vault.yml

# 5. Re-run playbook
ansible-playbook playbooks/setup.yml
```

### Accidentally Committed Plain Text

```bash
# 1. Remove from Git history immediately
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch group_vars/vault.yml" \
  --prune-empty --tag-name-filter cat -- --all

# 2. Force push (if already pushed)
git push origin --force --all

# 3. Rotate all secrets (they're now compromised)
ansible-vault edit group_vars/vault.yml

# 4. Encrypt properly
ansible-vault encrypt group_vars/vault.yml
```

---

## 📊 Vault File Structure

```
group_vars/
├── all.yml              # Non-sensitive config
│   └── References: {{ vault_xxx }}
│
└── vault.yml            # Encrypted secrets
    ├── vault_nas_credentials
    ├── vault_restic_passwords
    ├── vault_aws_credentials
    ├── vault_smtp_credentials
    └── vault_uptime_kuma_push_urls
```

---

## 🎯 Best Practices Checklist

- [ ] Strong vault password (32+ characters)
- [ ] Password file has chmod 600
- [ ] .vault_password in .gitignore
- [ ] Encrypted vault.yml committed to Git
- [ ] Plain text vault.yml NOT committed
- [ ] Vault password stored in password manager
- [ ] Team members have vault password securely
- [ ] Separate vaults for dev/staging/prod
- [ ] Regular vault password rotation
- [ ] All secrets use unique passwords
- [ ] Vault password backed up securely

---

## 💡 Pro Tips

```bash
# Generate strong password
openssl rand -base64 48 | head -c 32

# Check what's encrypted
find . -type f -exec grep -l '$ANSIBLE_VAULT' {} \;

# List all vault files
git ls-files | xargs grep -l '$ANSIBLE_VAULT'

# Diff encrypted files
ansible-vault diff group_vars/vault.yml group_vars/vault.yml.backup

# Encrypt inline in playbook
- name: Set password
  debug:
    msg: "{{ 'my-secret' | ansible.builtin.vault }}"
```

---

## 📚 Resources

- **Official Docs**: https://docs.ansible.com/ansible/latest/user_guide/vault.html
- **Best Practices**: https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html#variables-and-vaults
- **Vault Guide**: See VAULT_GUIDE.md for comprehensive documentation

---

**Keep this card handy for quick reference!** 🔐
