# Contributing to Server Helper

Thank you for your interest in contributing to Server Helper! This guide will help you get started with contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)
- [Community](#community)

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md) to keep our community approachable and respectable.

## Getting Started

### Prerequisites

Before you begin, ensure you have:

- **Git** installed
- **Python 3.8+** and **pip**
- **Ansible 2.10+**
- Access to an Ubuntu 24.04 LTS test environment (VM, container, or spare server)
- Basic knowledge of Ansible, YAML, and Docker

### Fork and Clone

1. **Fork** the repository on GitHub
2. **Clone** your fork locally:

```bash
git clone https://github.com/YOUR-USERNAME/Server-Helper.git
cd Server-Helper
```

3. **Add upstream** remote:

```bash
git remote add upstream https://github.com/thelasttenno/Server-Helper.git
```

4. **Install dependencies**:

```bash
ansible-galaxy install -r requirements.yml
pip3 install -r requirements.txt
```

### Setting Up Your Development Environment

1. **Create a test inventory**:

```bash
cp inventory/hosts.example.yml inventory/hosts.test.yml
# Edit with your test server details
nano inventory/hosts.test.yml
```

2. **Create test configuration**:

```bash
cp group_vars/all.example.yml group_vars/all.test.yml
# Configure for testing
nano group_vars/all.test.yml
```

3. **Set up Ansible Vault** for testing:

```bash
# Create a test vault password
echo "test-vault-password" > .vault_password.test
chmod 600 .vault_password.test

# Create test vault file
ansible-vault create group_vars/vault.test.yml --vault-password-file .vault_password.test
```

## Development Workflow

### Branching Strategy

We use a simple Git Flow workflow:

- **`main`**: Production-ready code
- **`develop`**: Integration branch for features
- **Feature branches**: `feature/description`
- **Bug fixes**: `fix/description`
- **Hotfixes**: `hotfix/description`

### Creating a Feature Branch

```bash
# Update your local main
git checkout main
git pull upstream main

# Create feature branch
git checkout -b feature/your-feature-name

# Make your changes
# ...

# Commit with descriptive messages
git add .
git commit -m "Add feature: description of what you added"

# Push to your fork
git push origin feature/your-feature-name
```

### Commit Message Guidelines

Write clear, descriptive commit messages following this format:

```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting, missing semicolons, etc.
- `refactor`: Code restructuring without changing functionality
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**

```
feat: Add support for Backblaze B2 backups

Implements Restic backup integration with Backblaze B2 cloud storage.
Includes configuration options for bucket name, account credentials,
and retention policies.

Closes #123
```

```
fix: Resolve NAS mount timeout issue

Increases timeout for CIFS mounts from 30s to 60s to prevent
failures on slow networks.

Fixes #456
```

## Pull Request Process

### Before Submitting

1. **Test your changes** thoroughly:
   - Run playbooks in check mode: `ansible-playbook playbooks/setup.yml --check`
   - Test on a clean Ubuntu 24.04 LTS system
   - Verify idempotency (running twice should not cause changes)

2. **Update documentation**:
   - Update README.md if adding new features
   - Add/update comments in code
   - Update relevant documentation in `docs/`

3. **Run linters** (if available):
   ```bash
   ansible-lint playbooks/*.yml
   yamllint .
   ```

4. **Check for secrets**:
   - Ensure no passwords, API keys, or sensitive data in commits
   - Use Ansible Vault for all secrets

### Submitting a Pull Request

1. **Push your changes** to your fork
2. **Create a Pull Request** on GitHub
3. **Fill out the PR template** completely
4. **Link related issues** using keywords (Closes #123, Fixes #456)
5. **Request review** from maintainers

### PR Review Process

- Maintainers will review your PR within 3-5 business days
- Address any requested changes
- Once approved, a maintainer will merge your PR
- Your contribution will be included in the next release!

### PR Checklist

- [ ] Code follows project style guidelines
- [ ] Self-review of code completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] Changes tested on Ubuntu 24.04 LTS
- [ ] Playbooks are idempotent
- [ ] No secrets committed
- [ ] Commit messages are clear and descriptive

## Coding Standards

### Ansible Best Practices

1. **YAML Formatting**:
   - Use 2 spaces for indentation
   - Use `---` at the start of files
   - Quote strings when necessary

2. **Task Naming**:
   ```yaml
   # Good
   - name: Install Docker packages
     apt:
       name: "{{ item }}"
       state: present
     loop:
       - docker-ce
       - docker-ce-cli

   # Bad (no descriptive name)
   - apt:
       name: docker-ce
   ```

3. **Idempotency**:
   - Always ensure tasks can run multiple times safely
   - Use `changed_when` and `failed_when` appropriately
   - Test by running playbooks twice

4. **Variables**:
   - Use descriptive variable names: `restic_backup_schedule` not `schedule`
   - Define defaults in `defaults/main.yml`
   - Document variables in role README

5. **Handlers**:
   - Use handlers for service restarts
   - Name handlers descriptively: `Restart Docker service`

6. **Templates**:
   - Add Ansible-managed header to templates
   - Use `.j2` extension for Jinja2 templates

### Directory Structure

Follow the established directory structure:

```
roles/
├── role_name/
│   ├── tasks/
│   │   └── main.yml
│   ├── handlers/
│   │   └── main.yml
│   ├── templates/
│   │   └── config.j2
│   ├── defaults/
│   │   └── main.yml
│   ├── vars/
│   │   └── main.yml
│   ├── files/
│   └── README.md
```

### Security Practices

1. **Never commit secrets**:
   - Use Ansible Vault for passwords, API keys, tokens
   - Check `.gitignore` includes vault password files

2. **Validate user input**:
   - Use `assert` module for critical validations
   - Check for required variables

3. **Least privilege**:
   - Run tasks with minimal required permissions
   - Avoid `become: yes` unless necessary

4. **Secure defaults**:
   - Disable unnecessary services
   - Use strong default configurations

## Testing Guidelines

### Local Testing

1. **Syntax Check**:
   ```bash
   ansible-playbook playbooks/setup.yml --syntax-check
   ```

2. **Dry Run** (check mode):
   ```bash
   ansible-playbook playbooks/setup.yml --check
   ```

3. **Test on Clean System**:
   ```bash
   # Use Vagrant, Docker, or VM
   vagrant up
   ansible-playbook -i inventory/hosts.test.yml playbooks/setup.yml
   ```

4. **Idempotency Test**:
   ```bash
   # Run twice, second run should show no changes
   ansible-playbook playbooks/setup.yml
   ansible-playbook playbooks/setup.yml
   ```

### Test Checklist

- [ ] Playbook runs successfully on fresh Ubuntu 24.04
- [ ] Playbook is idempotent (no changes on second run)
- [ ] All services start and function correctly
- [ ] Backup tasks complete successfully
- [ ] Monitoring dashboards accessible
- [ ] Security hardening applied
- [ ] Documentation updated

## Documentation

### What to Document

1. **New Features**:
   - Add to README.md
   - Create detailed guide in `docs/guides/`
   - Update CHANGELOG.md

2. **Configuration Options**:
   - Document in role README
   - Add examples to `group_vars/all.example.yml`

3. **Code Comments**:
   - Explain WHY, not WHAT
   - Document complex logic
   - Add TODO/FIXME for known issues

### Documentation Style

- Use clear, concise language
- Include code examples
- Add screenshots for UI features
- Use markdown formatting
- Keep documentation up-to-date

## Working with Ansible Vault

### Adding Secrets

```bash
# Edit vault file
ansible-vault edit group_vars/vault.yml

# Add new secret
vault_new_secret: "secret_value"

# Reference in playbook
my_secret: "{{ vault_new_secret }}"
```

### Testing with Vault

```bash
# Run playbook with vault password
ansible-playbook playbooks/setup.yml --vault-password-file .vault_password

# Or use prompt
ansible-playbook playbooks/setup.yml --ask-vault-pass
```

## Community

### Getting Help

- **GitHub Discussions**: Ask questions, share ideas
- **Issues**: Report bugs, request features
- **Pull Requests**: Discuss implementation details

### Ways to Contribute

Not just code! You can contribute by:

- **Documentation**: Improve guides, fix typos
- **Bug Reports**: Help identify issues
- **Feature Requests**: Suggest improvements
- **Testing**: Test on different environments
- **Community Support**: Help others in discussions
- **Translations**: Translate documentation
- **Examples**: Share your configurations

### Issue Labels

- `good first issue`: Great for newcomers
- `help wanted`: Extra attention needed
- `bug`: Something isn't working
- `enhancement`: New feature or request
- `documentation`: Documentation improvements
- `question`: Further information requested

## Release Process

Server Helper uses an **automated release process** with semantic versioning and automated changelog generation.

### For Maintainers

Releases are created by pushing version tags. The workflow is:

1. Update CHANGELOG.md (move "Unreleased" items to new version)
2. Commit changelog: `git commit -m "docs: Update changelog for vX.Y.Z"`
3. Create and push tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z" && git push origin vX.Y.Z`
4. GitHub Actions automatically creates the release with notes

**See the complete guide:** [docs/development/release-process.md](docs/development/release-process.md)

### For Contributors

When submitting PRs:

- **Update CHANGELOG.md** under "Unreleased" section
- **Add appropriate labels** to your PR for automatic categorization
- Follow **semantic versioning** principles in your changes

**Exemptions:** Add `documentation`, `dependencies`, or `no-changelog` label for changes that don't need changelog entries

## Questions?

If you have questions about contributing:

- Open a [GitHub Discussion](https://github.com/thelasttenno/Server-Helper/discussions)
- Check existing [issues](https://github.com/thelasttenno/Server-Helper/issues)
- Read the [documentation](docs/)

## Thank You!

Your contributions make Server Helper better for everyone. We appreciate your time and effort!

---

**Happy Contributing!** 🎉
