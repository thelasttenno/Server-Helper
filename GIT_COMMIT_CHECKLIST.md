# Git Commit Checklist - Ansible Vault Security

Before committing to Git, verify these critical security items:

---

## 🔐 Critical Security Checks

### 1. Vault Password Protection

```bash
# Verify .vault_password is NOT tracked
git status | grep .vault_password

# Should return nothing! If it shows up:
git rm --cached .vault_password
git commit -m "Remove vault password from tracking"

# Verify it's in .gitignore
grep "vault_password" .gitignore

# Output should show multiple patterns like:
# .vault_password
# .vault_password_*
# *.vault_pass
```

### 2. Vault File is Encrypted

```bash
# Check if vault.yml is encrypted
head -1 group_vars/vault.yml

# Should show: $ANSIBLE_VAULT;1.1;AES256...
# If you see plain text, STOP! Encrypt it:
ansible-vault encrypt group_vars/vault.yml
```

### 3. Actual Config Files NOT Tracked

```bash
# Verify actual config is ignored
git status | grep -E "(group_vars/all.yml|inventory/hosts.yml)"

# Should return nothing! If they show up:
git rm --cached group_vars/all.yml inventory/hosts.yml
git commit -m "Remove actual config files from tracking"

# Only .example.yml versions should be tracked
git ls-files | grep example
```

### 4. No SSH Keys in Repo

```bash
# Check for SSH keys
find . -name "*.pem" -o -name "*.key" -o -name "id_rsa*"

# Should return nothing! If found:
git rm --cached *.pem *.key id_rsa*
# Add to .gitignore if not already there
```

### 5. No Plain Text Secrets

```bash
# Search for potential plain text secrets
git diff --cached | grep -i -E "(password|secret|key|token)" | grep -v "vault_"

# Review any matches - they should reference vault variables like:
# password: "{{ vault_nas_password }}"
# NOT plain text like:
# password: "myPlainTextPassword123"  # ❌ DON'T COMMIT THIS!
```

---

## ✅ Safe to Commit Checklist

Check each item before `git commit`:

- [ ] `.vault_password` is in .gitignore
- [ ] `.vault_password` is NOT in `git status`
- [ ] `group_vars/vault.yml` shows $ANSIBLE_VAULT (encrypted)
- [ ] `group_vars/all.yml` (actual config) is NOT tracked
- [ ] `inventory/hosts.yml` (actual inventory) is NOT tracked
- [ ] Only `*.example.yml` versions are tracked
- [ ] No `.pem`, `.key`, or SSH key files
- [ ] No plain text passwords in diffs
- [ ] `.gitignore` is comprehensive
- [ ] All secrets reference `{{ vault_xxx }}` variables

---

## 📋 What SHOULD Be Committed

```bash
# Check what will be committed
git status

# Safe files:
✅ Documentation (*.md)
✅ Playbooks (playbooks/*.yml)
✅ Roles (roles/*/tasks/*.yml)
✅ Templates (*.j2)
✅ Example configs (*.example.yml)
✅ Encrypted vault.yml (when encrypted!)
✅ .gitignore
✅ ansible.cfg
✅ requirements.yml
✅ requirements.txt
```

---

## ❌ What MUST NOT Be Committed

```bash
# These should NEVER be in git status:
❌ .vault_password
❌ .vault_password_*
❌ group_vars/all.yml
❌ inventory/hosts.yml
❌ *.pem, *.key
❌ Any file with plain text passwords
❌ *_decrypted.yml
```

---

## 🔍 Pre-Commit Verification Commands

```bash
# 1. Check git status
git status

# 2. Check what will be added
git add --dry-run .

# 3. Review staged changes
git diff --cached

# 4. Verify encrypted files
git diff --cached | grep '$ANSIBLE_VAULT'

# 5. Search for potential secrets (should find none or only vault references)
git diff --cached | grep -i 'password' | grep -v 'vault_'
git diff --cached | grep -i 'secret' | grep -v 'vault_'
git diff --cached | grep -i 'token' | grep -v 'vault_'
```

---

## 🚨 If You Accidentally Committed Secrets

### Immediate Action (Before Push)

```bash
# 1. Undo last commit (keeps changes)
git reset --soft HEAD~1

# 2. Remove sensitive file from staging
git rm --cached path/to/sensitive/file

# 3. Add to .gitignore
echo "path/to/sensitive/file" >> .gitignore

# 4. Commit again (properly)
git add .
git commit -m "Proper commit without secrets"
```

### If Already Pushed to GitHub

```bash
# ⚠️ WARNING: This rewrites Git history!

# 1. Remove from all history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch path/to/secret/file" \
  --prune-empty --tag-name-filter cat -- --all

# 2. Force push
git push origin --force --all
git push origin --force --tags

# 3. CRITICAL: Rotate all exposed secrets immediately
# - Change all passwords
# - Regenerate API keys
# - Update vault with new secrets
ansible-vault edit group_vars/vault.yml

# 4. Inform team
# Alert team members to pull fresh repo
```

### If Secrets Are Exposed

**CRITICAL - Act within 1 hour:**

1. **Rotate ALL secrets** exposed in the commit
2. **Change vault password** immediately
3. **Update vault.yml** with new secrets
4. **Re-run playbooks** to apply new credentials
5. **Monitor services** for unauthorized access
6. **Review logs** for suspicious activity

---

## ✅ Safe Commit Process

```bash
# 1. Stage only safe files
git add README.md CHANGELOG.md
git add playbooks/*.yml
git add roles/
git add group_vars/*.example.yml
git add group_vars/vault.yml  # Only if encrypted!

# 2. Verify staged files
git status
git diff --cached

# 3. Final security check
./scripts/pre-commit-check.sh  # If you create this script

# 4. Commit
git commit -m "feat: Add Ansible Vault support for secure secrets"

# 5. One more check before push
git log -1 -p  # Review last commit

# 6. Push
git push origin main
```

---

## 🔒 Create Pre-Commit Hook (Optional but Recommended)

```bash
# Create pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook to prevent committing secrets

echo "🔐 Running security checks..."

# Check for vault password
if git diff --cached --name-only | grep -qE "\.vault_password|vault_pass"; then
    echo "❌ ERROR: Attempting to commit vault password!"
    echo "Remove with: git rm --cached .vault_password"
    exit 1
fi

# Check for plain text vault files
if git diff --cached group_vars/vault.yml | grep -qv '$ANSIBLE_VAULT'; then
    if git diff --cached group_vars/vault.yml | grep -q '^+'; then
        echo "❌ ERROR: vault.yml appears to be plain text!"
        echo "Encrypt with: ansible-vault encrypt group_vars/vault.yml"
        exit 1
    fi
fi

# Check for SSH keys
if git diff --cached --name-only | grep -qE '\.(pem|key)$|id_rsa|id_ed25519'; then
    echo "❌ ERROR: Attempting to commit SSH keys!"
    exit 1
fi

# Check for actual config files
if git diff --cached --name-only | grep -qE "group_vars/all\.yml|inventory/hosts\.yml"; then
    echo "⚠️  WARNING: Committing actual config file (not .example)"
    read -p "Are you sure? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✅ Security checks passed"
EOF

# Make executable
chmod +x .git/hooks/pre-commit
```

---

## 📊 Verification Script

Create `scripts/verify-security.sh`:

```bash
#!/bin/bash
# Verify repository security

echo "🔐 Server Helper Security Verification"
echo "======================================"
echo ""

FAILED=0

# Check 1: .vault_password not tracked
if git ls-files | grep -q "vault_password"; then
    echo "❌ FAIL: .vault_password is tracked in Git!"
    FAILED=1
else
    echo "✅ PASS: .vault_password not tracked"
fi

# Check 2: vault.yml is encrypted
if [ -f "group_vars/vault.yml" ]; then
    if head -1 group_vars/vault.yml | grep -q '$ANSIBLE_VAULT'; then
        echo "✅ PASS: vault.yml is encrypted"
    else
        echo "❌ FAIL: vault.yml is NOT encrypted!"
        FAILED=1
    fi
else
    echo "⚠️  WARN: vault.yml does not exist"
fi

# Check 3: Actual configs not tracked
if git ls-files | grep -qE "group_vars/all\.yml|inventory/hosts\.yml"; then
    echo "❌ FAIL: Actual config files are tracked!"
    FAILED=1
else
    echo "✅ PASS: Actual config files not tracked"
fi

# Check 4: No SSH keys
if git ls-files | grep -qE '\.(pem|key)$'; then
    echo "❌ FAIL: SSH keys found in repository!"
    FAILED=1
else
    echo "✅ PASS: No SSH keys in repository"
fi

# Check 5: .gitignore exists and has vault patterns
if [ -f ".gitignore" ] && grep -q "vault_password" .gitignore; then
    echo "✅ PASS: .gitignore configured for vault"
else
    echo "❌ FAIL: .gitignore not properly configured!"
    FAILED=1
fi

echo ""
echo "======================================"
if [ $FAILED -eq 0 ]; then
    echo "✅ All security checks passed!"
    exit 0
else
    echo "❌ Security issues detected!"
    exit 1
fi
```

Run before every commit:
```bash
chmod +x scripts/verify-security.sh
./scripts/verify-security.sh
```

---

## 📝 Final Checklist Before Release

- [ ] All security checks passed
- [ ] `./scripts/verify-security.sh` returns success
- [ ] Pre-commit hook installed
- [ ] Team members notified of vault password location
- [ ] Backup of vault password in password manager
- [ ] Documentation reviewed
- [ ] README.md includes vault section
- [ ] VAULT_GUIDE.md is comprehensive
- [ ] All example files have `.example` suffix
- [ ] Git history clean (no exposed secrets)

---

## 💡 Best Practice

**Before every commit:**

```bash
# Run verification
./scripts/verify-security.sh

# Review changes
git diff --cached

# Search for potential issues
git diff --cached | grep -i -E "(password|secret|key)" | grep -v "vault_"

# Commit only if all clear
git commit -m "Your commit message"
```

---

**Remember: Security is a process, not a one-time setup!** 🔐

Always verify before committing. When in doubt, don't commit - ask for review.
