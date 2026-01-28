# External Secret Management Integration

This guide shows how to integrate Server Helper with external secret management systems as alternatives or complements to Ansible Vault.

---

## 🔐 Supported Secret Managers

Server Helper can integrate with:

1. **HashiCorp Vault** - Enterprise secret management
2. **AWS Systems Manager Parameter Store** - AWS-native secrets
3. **AWS Secrets Manager** - Managed secret rotation
4. **Azure Key Vault** - Azure-native secrets
5. **Google Cloud Secret Manager** - GCP-native secrets
6. **1Password** - Team password manager
7. **Environment Variables** - Simple CI/CD integration

---

## 🏗️ Integration Patterns

### Pattern 1: Hybrid (Recommended)

Use Ansible Vault for most secrets + External system for highly sensitive data:

```yaml
# group_vars/all.yml
restic:
  destinations:
    s3:
      # Regular secrets in Ansible Vault
      password: "{{ vault_restic_passwords.s3 }}"

      # Highly sensitive from external system
      access_key: "{{ lookup('hashivault', 'aws/s3', 'access_key') }}"
      secret_key: "{{ lookup('hashivault', 'aws/s3', 'secret_key') }}"
```

**Benefits:**
- ✅ Best security for critical secrets
- ✅ Audit logs from external system
- ✅ Automatic rotation (if supported)
- ✅ Fallback to Ansible Vault

### Pattern 2: Full External

Store ALL secrets in external system:

```yaml
# group_vars/all.yml
restic:
  destinations:
    s3:
      access_key: "{{ lookup('env', 'AWS_ACCESS_KEY_ID') }}"
      secret_key: "{{ lookup('env', 'AWS_SECRET_ACCESS_KEY') }}"
      password: "{{ lookup('hashivault', 'restic/s3', 'password') }}"
```

**Benefits:**
- ✅ Centralized secret management
- ✅ Better audit trails
- ✅ Automatic rotation

**Drawbacks:**
- ❌ Requires external system availability
- ❌ More complex setup
- ❌ Network dependency

### Pattern 3: CI/CD Only

Use Ansible Vault locally + Environment variables in CI/CD:

```yaml
# group_vars/all.yml
restic:
  destinations:
    s3:
      # Ansible Vault locally, env var in CI/CD
      access_key: "{{ lookup('env', 'AWS_ACCESS_KEY_ID') | default(vault_aws_credentials.access_key) }}"
      secret_key: "{{ lookup('env', 'AWS_SECRET_ACCESS_KEY') | default(vault_aws_credentials.secret_key) }}"
```

**Benefits:**
- ✅ Secure local development
- ✅ No secrets in CI/CD config
- ✅ Simple setup

---

## 1. HashiCorp Vault

### Setup

```bash
# Install Ansible plugin
pip3 install hvac

# Configure Vault connection
export VAULT_ADDR="https://vault.example.com:8200"
export VAULT_TOKEN="your-vault-token"
```

### Store Secrets in Vault

```bash
# Store NAS credentials
vault kv put secret/server-helper/nas \
  username="nasuser" \
  password="naspass123"

# Store Restic passwords
vault kv put secret/server-helper/restic \
  nas="restic-nas-password" \
  s3="restic-s3-password" \
  b2="restic-b2-password"

# Store AWS credentials
vault kv put secret/server-helper/aws \
  access_key="AKIAIOSFODNN7EXAMPLE" \
  secret_key="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

### Use in Ansible

```yaml
# group_vars/all.yml
---
nas:
  enabled: true
  shares:
    - ip: "192.168.1.100"
      share: "backup"
      mount: "/mnt/nas/backup"
      # Fetch from Vault
      username: "{{ lookup('community.hashi_vault.vault_kv2_get', 'secret/server-helper/nas').secret.username }}"
      password: "{{ lookup('community.hashi_vault.vault_kv2_get', 'secret/server-helper/nas').secret.password }}"

restic:
  destinations:
    s3:
      enabled: true
      access_key: "{{ lookup('community.hashi_vault.vault_kv2_get', 'secret/server-helper/aws').secret.access_key }}"
      secret_key: "{{ lookup('community.hashi_vault.vault_kv2_get', 'secret/server-helper/aws').secret.secret_key }}"
      password: "{{ lookup('community.hashi_vault.vault_kv2_get', 'secret/server-helper/restic').secret.s3 }}"
```

### Install Vault Collection

```bash
# Install community Vault collection
ansible-galaxy collection install community.hashi_vault
```

### Vault Policy Example

```hcl
# server-helper-policy.hcl
path "secret/data/server-helper/*" {
  capabilities = ["read", "list"]
}
```

---

## 2. AWS Systems Manager Parameter Store

### Setup

```bash
# Install boto3
pip3 install boto3

# Configure AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### Store Secrets in Parameter Store

```bash
# Store NAS credentials
aws ssm put-parameter \
  --name "/server-helper/nas/username" \
  --value "nasuser" \
  --type "String"

aws ssm put-parameter \
  --name "/server-helper/nas/password" \
  --value "naspass123" \
  --type "SecureString"

# Store Restic passwords
aws ssm put-parameter \
  --name "/server-helper/restic/nas-password" \
  --value "restic-nas-password" \
  --type "SecureString"

# Store AWS credentials (for other services)
aws ssm put-parameter \
  --name "/server-helper/backup/s3-access-key" \
  --value "AKIAIOSFODNN7EXAMPLE" \
  --type "SecureString"
```

### Use in Ansible

```yaml
# group_vars/all.yml
---
nas:
  shares:
    - username: "{{ lookup('aws_ssm', '/server-helper/nas/username') }}"
      password: "{{ lookup('aws_ssm', '/server-helper/nas/password', decrypt=true) }}"

restic:
  destinations:
    s3:
      access_key: "{{ lookup('aws_ssm', '/server-helper/backup/s3-access-key', decrypt=true) }}"
      password: "{{ lookup('aws_ssm', '/server-helper/restic/nas-password', decrypt=true) }}"
```

### IAM Policy Example

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/server-helper/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": "arn:aws:kms:*:*:key/*"
    }
  ]
}
```

---

## 3. AWS Secrets Manager

### Setup

```bash
# Install boto3 (if not already installed)
pip3 install boto3

# Configure AWS credentials (same as Parameter Store)
```

### Store Secrets

```bash
# Store NAS credentials as JSON
aws secretsmanager create-secret \
  --name "server-helper/nas" \
  --secret-string '{"username":"nasuser","password":"naspass123"}'

# Store Restic passwords
aws secretsmanager create-secret \
  --name "server-helper/restic" \
  --secret-string '{"nas":"restic-nas-password","s3":"restic-s3-password"}'
```

### Use in Ansible

```yaml
# group_vars/all.yml
---
nas:
  shares:
    - username: "{{ lookup('aws_secret', 'server-helper/nas', region='us-east-1') | from_json | json_query('username') }}"
      password: "{{ lookup('aws_secret', 'server-helper/nas', region='us-east-1') | from_json | json_query('password') }}"

restic:
  destinations:
    s3:
      password: "{{ lookup('aws_secret', 'server-helper/restic', region='us-east-1') | from_json | json_query('s3') }}"
```

### Enable Automatic Rotation

```bash
# Enable rotation (requires Lambda function)
aws secretsmanager rotate-secret \
  --secret-id "server-helper/nas" \
  --rotation-lambda-arn "arn:aws:lambda:us-east-1:123456789012:function:SecretsManagerRotation" \
  --rotation-rules AutomaticallyAfterDays=30
```

---

## 4. Azure Key Vault

### Setup

```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login
az login

# Install Ansible Azure collection
ansible-galaxy collection install azure.azcollection
pip3 install -r ~/.ansible/collections/ansible_collections/azure/azcollection/requirements-azure.txt
```

### Store Secrets

```bash
# Create Key Vault (one-time)
az keyvault create \
  --name "server-helper-vault" \
  --resource-group "my-resource-group" \
  --location "eastus"

# Store secrets
az keyvault secret set \
  --vault-name "server-helper-vault" \
  --name "nas-username" \
  --value "nasuser"

az keyvault secret set \
  --vault-name "server-helper-vault" \
  --name "nas-password" \
  --value "naspass123"

az keyvault secret set \
  --vault-name "server-helper-vault" \
  --name "restic-nas-password" \
  --value "restic-nas-password"
```

### Use in Ansible

```yaml
# group_vars/all.yml
---
nas:
  shares:
    - username: "{{ lookup('azure.azcollection.azure_keyvault_secret', 'nas-username', vault_url='https://server-helper-vault.vault.azure.net/') }}"
      password: "{{ lookup('azure.azcollection.azure_keyvault_secret', 'nas-password', vault_url='https://server-helper-vault.vault.azure.net/') }}"
```

---

## 5. Google Cloud Secret Manager

### Setup

```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash

# Login and set project
gcloud auth login
gcloud config set project my-project-id

# Install Python library
pip3 install google-cloud-secret-manager
```

### Store Secrets

```bash
# Store secrets
echo -n "nasuser" | gcloud secrets create nas-username --data-file=-
echo -n "naspass123" | gcloud secrets create nas-password --data-file=-
echo -n "restic-nas-password" | gcloud secrets create restic-nas-password --data-file=-
```

### Use in Ansible

```yaml
# group_vars/all.yml
---
nas:
  shares:
    - username: "{{ lookup('google.cloud.gcp_secret_manager', 'nas-username', project='my-project-id') }}"
      password: "{{ lookup('google.cloud.gcp_secret_manager', 'nas-password', project='my-project-id') }}"
```

### IAM Permissions

```bash
# Grant secret accessor role
gcloud secrets add-iam-policy-binding nas-password \
  --member="serviceAccount:ansible@my-project.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

---

## 6. 1Password

### Setup

```bash
# Install 1Password CLI
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
  sudo tee /etc/apt/sources.list.d/1password.list

sudo apt update && sudo apt install 1password-cli

# Sign in
op signin
```

### Store Secrets in 1Password

Create items in 1Password with these naming conventions:

- Vault: `Server Helper`
- Items:
  - `NAS Credentials` (username/password fields)
  - `Restic NAS Password` (password field)
  - `AWS S3 Credentials` (access key/secret key fields)

### Use with Ansible

```bash
# Create wrapper script: scripts/get-1password-secret.sh
#!/bin/bash
VAULT="Server Helper"
ITEM="$1"
FIELD="$2"
op read "op://$VAULT/$ITEM/$FIELD"
```

```yaml
# group_vars/all.yml
---
nas:
  shares:
    - username: "{{ lookup('pipe', './scripts/get-1password-secret.sh \"NAS Credentials\" username') }}"
      password: "{{ lookup('pipe', './scripts/get-1password-secret.sh \"NAS Credentials\" password') }}"

restic:
  destinations:
    nas:
      password: "{{ lookup('pipe', './scripts/get-1password-secret.sh \"Restic NAS Password\" password') }}"
```

---

## 7. Environment Variables (CI/CD)

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy Server Helper

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run Ansible Playbook
        env:
          # Set from GitHub Secrets
          ANSIBLE_VAULT_PASSWORD: ${{ secrets.ANSIBLE_VAULT_PASSWORD }}
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          NAS_PASSWORD: ${{ secrets.NAS_PASSWORD }}
        run: |
          echo "$ANSIBLE_VAULT_PASSWORD" > .vault_password
          ansible-playbook playbooks/setup.yml
```

### GitLab CI

```yaml
# .gitlab-ci.yml
deploy:
  stage: deploy
  script:
    - echo "$ANSIBLE_VAULT_PASSWORD" > .vault_password
    - ansible-playbook playbooks/setup.yml
  variables:
    AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
  only:
    - main
```

### Use in Ansible

```yaml
# group_vars/all.yml
---
# Prefer environment variable, fallback to Ansible Vault
nas:
  shares:
    - username: "{{ lookup('env', 'NAS_USERNAME') | default(vault_nas_credentials[0].username) }}"
      password: "{{ lookup('env', 'NAS_PASSWORD') | default(vault_nas_credentials[0].password) }}"

restic:
  destinations:
    s3:
      access_key: "{{ lookup('env', 'AWS_ACCESS_KEY_ID') | default(vault_aws_credentials.access_key) }}"
      secret_key: "{{ lookup('env', 'AWS_SECRET_ACCESS_KEY') | default(vault_aws_credentials.secret_key) }}"
```

---

## 🔄 Migration Strategies

### From Ansible Vault to External System

```bash
# 1. Extract secrets from vault
ansible-vault view group_vars/vault.yml > /tmp/vault_plain.yml

# 2. Load secrets into external system (example: AWS SSM)
while IFS=: read -r key value; do
  aws ssm put-parameter \
    --name "/server-helper/$key" \
    --value "$value" \
    --type "SecureString"
done < <(grep -v '^#' /tmp/vault_plain.yml | grep -v '^$')

# 3. Update group_vars/all.yml to use lookups
# (See examples above)

# 4. Test with dry run
ansible-playbook playbooks/setup.yml --check

# 5. Delete plain text file
shred -u /tmp/vault_plain.yml
```

### From External System to Ansible Vault

```bash
# 1. Fetch secrets from external system
# (Example for AWS SSM)
aws ssm get-parameters-by-path \
  --path "/server-helper/" \
  --with-decryption \
  --query "Parameters[*].[Name,Value]" \
  --output text > /tmp/secrets.txt

# 2. Format as YAML
# 3. Encrypt with Ansible Vault
ansible-vault create group_vars/vault.yml
# (Paste formatted YAML)

# 4. Update references in group_vars/all.yml
# 5. Test
ansible-playbook playbooks/setup.yml --check
```

---

## 🎯 Best Practices

### Security

- ✅ Use different credentials for dev/staging/prod
- ✅ Enable audit logging in secret manager
- ✅ Implement least privilege access
- ✅ Rotate secrets regularly
- ✅ Use encryption at rest and in transit

### Availability

- ✅ Implement fallback mechanisms
- ✅ Cache secrets when appropriate
- ✅ Handle secret manager outages gracefully
- ✅ Test disaster recovery procedures

### Operations

- ✅ Document which secrets are where
- ✅ Automate secret rotation
- ✅ Monitor secret access
- ✅ Have a secrets inventory
- ✅ Test secret retrieval in CI/CD

---

## 📋 Comparison Matrix

| Feature | Ansible Vault | HashiCorp Vault | AWS Secrets Mgr | Azure Key Vault | GCP Secret Mgr |
|---------|---------------|-----------------|-----------------|-----------------|----------------|
| **Cost** | Free | Free/Paid | $$$ | $$$ | $$$ |
| **Complexity** | Low | Medium | Low | Low | Low |
| **Audit Logs** | Git only | ✅ Full | ✅ Full | ✅ Full | ✅ Full |
| **Auto Rotation** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Offline Use** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Team Sharing** | Git | ✅ Native | ✅ Native | ✅ Native | ✅ Native |
| **Versioning** | Git | ✅ | ✅ | ✅ | ✅ |
| **Integration** | Native | Plugin | Plugin | Plugin | Plugin |
| **Best For** | Simple setups | Enterprise | AWS users | Azure users | GCP users |

---

## 🚨 Troubleshooting

### Secret Lookup Fails

```bash
# Test lookup manually
ansible localhost -m debug -a "var=lookup('aws_ssm', '/server-helper/nas/username')"

# Check credentials
aws sts get-caller-identity

# Enable Ansible verbose mode
ansible-playbook playbooks/setup.yml -vvv
```

### Connection Timeouts

```bash
# Check network connectivity
curl -v https://vault.example.com:8200/v1/sys/health

# Test with increased timeout
ANSIBLE_TIMEOUT=60 ansible-playbook playbooks/setup.yml
```

### Permission Denied

```bash
# Check IAM permissions (AWS)
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/ansible \
  --action-names ssm:GetParameter

# Check Vault policy (HashiCorp)
vault policy read server-helper-policy
```

---

## 📚 Additional Resources

- **HashiCorp Vault Docs**: https://www.vaultproject.io/docs
- **AWS SSM Docs**: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html
- **Ansible Lookups**: https://docs.ansible.com/ansible/latest/plugins/lookup.html
- **1Password CLI**: https://developer.1password.com/docs/cli

---

**Remember: The best secret management strategy is the one you can maintain securely!** 🔐
