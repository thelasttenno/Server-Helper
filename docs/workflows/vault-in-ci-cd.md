# Ansible Vault in CI/CD Workflows

Complete guide for integrating Ansible Vault with CI/CD pipelines and automation workflows.

---

## 🎯 Overview

This guide covers:

1. **CI/CD Integration** - GitHub Actions, GitLab CI, Jenkins, etc.
2. **Git Workflows** - Hooks, pre-commit, automation
3. **Team Collaboration** - Best practices for teams
4. **Secret Rotation** - Automated rotation strategies

---

## 🚀 CI/CD Integration

### GitHub Actions

#### Basic Setup

```yaml
# .github/workflows/deploy.yml
name: Deploy with Ansible

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install Ansible
        run: |
          pip install ansible

      - name: Install requirements
        run: |
          ansible-galaxy install -r requirements.yml

      - name: Create vault password file
        env:
          ANSIBLE_VAULT_PASSWORD: ${{ secrets.ANSIBLE_VAULT_PASSWORD }}
        run: |
          echo "$ANSIBLE_VAULT_PASSWORD" > .vault_password
          chmod 600 .vault_password

      - name: Verify vault can be decrypted
        run: |
          ansible-vault view group_vars/vault.yml --vault-password-file .vault_password > /dev/null

      - name: Run playbook (dry run)
        if: github.event_name == 'pull_request'
        run: |
          ansible-playbook playbooks/setup.yml --check

      - name: Run playbook (production)
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: |
          ansible-playbook playbooks/setup.yml

      - name: Clean up vault password
        if: always()
        run: |
          shred -u .vault_password || rm -f .vault_password
```

#### Advanced: Multiple Environments

```yaml
# .github/workflows/deploy-multi-env.yml
name: Deploy Multi-Environment

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - staging
          - production

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment }}

    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install Ansible
        run: pip install ansible

      - name: Create vault password file
        env:
          # Different secrets for each environment
          VAULT_PASSWORD: ${{ secrets[format('VAULT_PASSWORD_{0}', github.event.inputs.environment)] }}
        run: |
          echo "$VAULT_PASSWORD" > .vault_password
          chmod 600 .vault_password

      - name: Deploy to ${{ github.event.inputs.environment }}
        run: |
          ansible-playbook playbooks/setup.yml \
            -i inventory/${{ github.event.inputs.environment }}.yml \
            --vault-password-file .vault_password

      - name: Clean up
        if: always()
        run: shred -u .vault_password || rm -f .vault_password
```

#### Setting GitHub Secrets

```bash
# Via GitHub CLI
gh secret set ANSIBLE_VAULT_PASSWORD < .vault_password

# Or via web UI:
# Settings → Secrets and variables → Actions → New repository secret
# Name: ANSIBLE_VAULT_PASSWORD
# Value: (paste vault password)
```

---

### GitLab CI/CD

#### Basic Pipeline

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - deploy

variables:
  ANSIBLE_FORCE_COLOR: "true"
  ANSIBLE_HOST_KEY_CHECKING: "false"

before_script:
  - apt-get update -qq
  - apt-get install -y python3-pip
  - pip3 install ansible
  - ansible-galaxy install -r requirements.yml
  - echo "$ANSIBLE_VAULT_PASSWORD" > .vault_password
  - chmod 600 .vault_password

after_script:
  - shred -u .vault_password || rm -f .vault_password

validate:
  stage: validate
  script:
    - ansible-vault view group_vars/vault.yml --vault-password-file .vault_password > /dev/null
    - ansible-playbook playbooks/setup.yml --syntax-check
    - ansible-playbook playbooks/setup.yml --check
  only:
    - merge_requests

deploy_dev:
  stage: deploy
  script:
    - ansible-playbook playbooks/setup.yml -i inventory/dev.yml
  environment:
    name: development
  only:
    - develop

deploy_prod:
  stage: deploy
  script:
    - ansible-playbook playbooks/setup.yml -i inventory/prod.yml
  environment:
    name: production
  when: manual
  only:
    - main
```

#### Protected Variables

```bash
# Set in GitLab:
# Settings → CI/CD → Variables
# Key: ANSIBLE_VAULT_PASSWORD
# Value: (paste vault password)
# ✅ Protected
# ✅ Masked
# ✅ Environment scope: All / Specific
```

---

### Jenkins

#### Jenkinsfile

```groovy
// Jenkinsfile
pipeline {
    agent any

    environment {
        ANSIBLE_FORCE_COLOR = 'true'
        ANSIBLE_HOST_KEY_CHECKING = 'false'
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    // Install Ansible
                    sh 'pip3 install ansible'
                    sh 'ansible-galaxy install -r requirements.yml'

                    // Create vault password file from Jenkins credential
                    withCredentials([string(credentialsId: 'ansible-vault-password', variable: 'VAULT_PASS')]) {
                        sh '''
                            echo "$VAULT_PASS" > .vault_password
                            chmod 600 .vault_password
                        '''
                    }
                }
            }
        }

        stage('Validate') {
            steps {
                sh 'ansible-vault view group_vars/vault.yml --vault-password-file .vault_password > /dev/null'
                sh 'ansible-playbook playbooks/setup.yml --syntax-check'
                sh 'ansible-playbook playbooks/setup.yml --check'
            }
        }

        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh 'ansible-playbook playbooks/setup.yml'
            }
        }
    }

    post {
        always {
            sh 'shred -u .vault_password || rm -f .vault_password'
        }
    }
}
```

#### Adding Jenkins Credential

```groovy
// Via Jenkins UI:
// Manage Jenkins → Credentials → System → Global credentials → Add Credentials
// Kind: Secret text
// Scope: Global
// Secret: (paste vault password)
// ID: ansible-vault-password
// Description: Ansible Vault Password
```

---

### Azure DevOps

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main
      - develop

pool:
  vmImage: 'ubuntu-latest'

variables:
  - group: ansible-vault-passwords  # Variable group with vault password

steps:
  - task: UsePythonVersion@0
    inputs:
      versionSpec: '3.11'
    displayName: 'Use Python 3.11'

  - script: |
      pip install ansible
      ansible-galaxy install -r requirements.yml
    displayName: 'Install Ansible'

  - script: |
      echo "$(ANSIBLE_VAULT_PASSWORD)" > .vault_password
      chmod 600 .vault_password
    displayName: 'Create vault password file'
    env:
      ANSIBLE_VAULT_PASSWORD: $(ANSIBLE_VAULT_PASSWORD)

  - script: |
      ansible-vault view group_vars/vault.yml --vault-password-file .vault_password > /dev/null
    displayName: 'Verify vault'

  - script: |
      ansible-playbook playbooks/setup.yml --check
    displayName: 'Dry run'
    condition: eq(variables['Build.Reason'], 'PullRequest')

  - script: |
      ansible-playbook playbooks/setup.yml
    displayName: 'Deploy'
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))

  - script: |
      shred -u .vault_password || rm -f .vault_password
    displayName: 'Clean up'
    condition: always()
```

---

## 🔄 Git Workflow Integration

### Pre-commit Hooks

Prevent committing plain text secrets:

```bash
# Install pre-commit
pip install pre-commit

# Create .pre-commit-config.yaml
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: local
    hooks:
      # Prevent committing vault password files
      - id: check-vault-password
        name: Check for vault password files
        entry: bash -c 'if git diff --cached --name-only | grep -E "\.vault_password|vault_pass|\.vault_pass"; then echo "ERROR: Attempting to commit vault password file!"; exit 1; fi'
        language: system
        always_run: true

      # Ensure vault files are encrypted
      - id: check-vault-encrypted
        name: Check vault files are encrypted
        entry: bash -c 'for file in $(git diff --cached --name-only | grep -E "vault\.yml$"); do if [ -f "$file" ] && ! head -1 "$file" | grep -q "^\$ANSIBLE_VAULT"; then echo "ERROR: $file is not encrypted!"; exit 1; fi; done'
        language: system
        always_run: true

      # Check for plain text secrets
      - id: check-secrets
        name: Check for plain text secrets
        entry: bash -c 'if git diff --cached --name-only | grep -E "_plain\.yml$|_decrypted\.yml$"; then echo "ERROR: Attempting to commit plain text secrets!"; exit 1; fi'
        language: system
        always_run: true

  # Additional hooks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: check-yaml
        exclude: 'group_vars/vault.yml'  # Skip encrypted files
      - id: end-of-file-fixer
      - id: trailing-whitespace
      - id: check-added-large-files
        args: ['--maxkb=500']
EOF

# Install hooks
pre-commit install
```

### Git Diff for Encrypted Files

View diffs of encrypted vault files:

```bash
# Create diff script
cat > scripts/vault-diff.sh << 'EOF'
#!/bin/bash
# Usage: scripts/vault-diff.sh <file>

FILE="$1"
VAULT_PASSWORD_FILE=".vault_password"

if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
    echo "ERROR: Vault password file not found"
    exit 1
fi

# Show diff of decrypted content
git diff \
    --textconv="ansible-vault view --vault-password-file=$VAULT_PASSWORD_FILE" \
    "$FILE"
EOF

chmod +x scripts/vault-diff.sh

# Use it:
./scripts/vault-diff.sh group_vars/vault.yml
```

### Git Attributes

Configure git to handle vault files:

```bash
# Create .gitattributes
cat > .gitattributes << 'EOF'
# Treat vault files as binary to prevent unwanted diff attempts
**/vault.yml binary

# Use custom diff for vault files (optional)
# Requires: git config diff.ansible-vault.textconv "ansible-vault view"
**/vault.yml diff=ansible-vault
EOF

# Configure git diff driver (optional)
git config diff.ansible-vault.textconv "ansible-vault view --vault-password-file=.vault_password"
```

---

## 👥 Team Collaboration Workflows

### Onboarding New Team Member

```bash
# 1. Team lead generates vault password (if new team)
openssl rand -base64 32 > .vault_password

# 2. Share vault password securely
# - Via 1Password team vault
# - Via encrypted email
# - Via secure messaging (Signal, etc.)
# - In person

# 3. New team member setup
git clone https://github.com/your-org/Server-Helper.git
cd Server-Helper

# Create vault password file (from secure source)
echo "received-vault-password" > .vault_password
chmod 600 .vault_password

# Verify access
ansible-vault view group_vars/vault.yml

# Install pre-commit hooks
pre-commit install
```

### Offboarding Team Member

```bash
# 1. Rotate vault password
./scripts/vault-rekey.sh --all

# 2. Update CI/CD secrets
# GitHub: Settings → Secrets → Update ANSIBLE_VAULT_PASSWORD
# GitLab: Settings → CI/CD → Variables → Update
# Jenkins: Manage Jenkins → Credentials → Update

# 3. Share new password with remaining team
# 4. Rotate all secrets in vault (paranoid mode)
ansible-vault edit group_vars/vault.yml
# Change all passwords, API keys, etc.
```

### Code Review with Vault Changes

```bash
# Reviewer: View vault changes
./scripts/vault-diff.sh group_vars/vault.yml

# Or view current encrypted content
./scripts/vault-view.sh group_vars/vault.yml

# Check what changed in PR
git show HEAD:group_vars/vault.yml | \
  ansible-vault view --vault-password-file=.vault_password /dev/stdin
```

---

## 🔄 Secret Rotation Automation

### Automated Weekly Rotation

```bash
# Create rotation script: scripts/rotate-secrets.sh
#!/bin/bash
set -euo pipefail

# Rotate restic passwords
NEW_RESTIC_NAS_PASS=$(openssl rand -base64 32)
NEW_RESTIC_S3_PASS=$(openssl rand -base64 32)

# Update vault
ansible-vault edit group_vars/vault.yml << EOF
# Update these in the editor:
vault_restic_passwords:
  nas: "$NEW_RESTIC_NAS_PASS"
  s3: "$NEW_RESTIC_S3_PASS"
EOF

# Update restic repositories
sudo restic -r /mnt/nas/backup/restic change-password

# Re-run playbook to apply changes
ansible-playbook playbooks/setup.yml --tags restic

# Commit changes
git add group_vars/vault.yml
git commit -m "chore: rotate restic passwords (automated)"
git push
```

### Scheduled Rotation (GitHub Actions)

```yaml
# .github/workflows/rotate-secrets.yml
name: Rotate Secrets

on:
  schedule:
    # Run every Sunday at 2 AM
    - cron: '0 2 * * 0'
  workflow_dispatch:  # Allow manual trigger

jobs:
  rotate:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install Ansible
        run: pip install ansible

      - name: Create vault password
        env:
          VAULT_PASSWORD: ${{ secrets.ANSIBLE_VAULT_PASSWORD }}
        run: |
          echo "$VAULT_PASSWORD" > .vault_password
          chmod 600 .vault_password

      - name: Rotate secrets
        run: ./scripts/rotate-secrets.sh

      - name: Commit changes
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add group_vars/vault.yml
          git commit -m "chore: automated secret rotation" || echo "No changes"
          git push

      - name: Clean up
        if: always()
        run: shred -u .vault_password
```

---

## 🧪 Testing Vault in CI/CD

### Vault Validation Tests

```yaml
# .github/workflows/test-vault.yml
name: Test Vault Configuration

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install Ansible
        run: pip install ansible

      - name: Create vault password
        env:
          VAULT_PASSWORD: ${{ secrets.ANSIBLE_VAULT_PASSWORD }}
        run: |
          echo "$VAULT_PASSWORD" > .vault_password
          chmod 600 .vault_password

      - name: Test vault can be decrypted
        run: |
          ansible-vault view group_vars/vault.yml > /dev/null
          echo "✓ Vault decryption successful"

      - name: Validate vault structure
        run: |
          # Check required variables exist
          ansible-vault view group_vars/vault.yml | \
            grep -q "vault_nas_credentials" || \
            (echo "ERROR: vault_nas_credentials not found"; exit 1)

          ansible-vault view group_vars/vault.yml | \
            grep -q "vault_restic_passwords" || \
            (echo "ERROR: vault_restic_passwords not found"; exit 1)

          echo "✓ Vault structure valid"

      - name: Test playbook with vault
        run: |
          ansible-playbook playbooks/setup.yml --syntax-check
          ansible-playbook playbooks/setup.yml --check
          echo "✓ Playbook validation successful"

      - name: Clean up
        if: always()
        run: shred -u .vault_password
```

---

## 📋 Checklists

### CI/CD Setup Checklist

- [ ] Vault password stored in CI/CD secrets
- [ ] Vault password file created in pipeline
- [ ] Vault password file cleaned up after use
- [ ] Dry run enabled for PRs
- [ ] Production deployment requires approval
- [ ] Multiple environments configured (if needed)
- [ ] Error notifications configured
- [ ] Audit logs enabled

### Security Checklist

- [ ] Vault password never logged
- [ ] Vault password never in code
- [ ] Vault password file excluded from artifacts
- [ ] Temporary files shredded after use
- [ ] Pre-commit hooks installed
- [ ] Code review process for vault changes
- [ ] Secret rotation schedule defined
- [ ] Offboarding procedure documented

---

## 🚨 Troubleshooting

### Vault Decryption Fails in CI/CD

```bash
# Check secret is set correctly
# In GitHub Actions workflow, add debug step:
- name: Debug vault password
  run: |
    echo "Vault password length: ${#ANSIBLE_VAULT_PASSWORD}"
    # Don't print the actual password!

# Common issues:
# - Trailing newline in secret
# - Wrong secret variable name
# - Secret not accessible in environment
```

### File Permissions Issues

```bash
# Ensure vault password file has correct permissions
chmod 600 .vault_password

# In Docker containers
RUN chmod 600 .vault_password && chown ansible:ansible .vault_password
```

### Git Hooks Not Running

```bash
# Reinstall hooks
pre-commit uninstall
pre-commit install

# Test hooks manually
pre-commit run --all-files
```

---

## 📚 Additional Resources

- **GitHub Actions Secrets**: https://docs.github.com/en/actions/security-guides/encrypted-secrets
- **GitLab CI Variables**: https://docs.gitlab.com/ee/ci/variables/
- **Jenkins Credentials**: https://www.jenkins.io/doc/book/using/using-credentials/
- **Pre-commit Framework**: https://pre-commit.com/

---

**Remember: Automation should enhance security, not compromise it!** 🔒
