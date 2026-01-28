# Testing Quick Start Guide

Get started with testing Server-Helper playbooks in 5 minutes.

## Prerequisites

- Docker installed and running
- Python 3.11+ installed
- Git repository cloned

## Quick Setup

### 1. Install Dependencies

```bash
# Install all testing tools
pip install -r requirements-test.txt
```

### 2. Run Your First Test

```bash
# Test the common role
cd roles/common
molecule test
```

That's it! Molecule will:
1. Create a Docker container
2. Run the role against it
3. Validate everything works
4. Clean up the container

## Common Commands

### Test All Roles

```bash
# From project root
make test

# Or manually:
./scripts/test-all-roles.sh
```

### Test Specific Role

```bash
# Using make
make test-role ROLE=common

# Or manually
cd roles/common
molecule test
```

### Step-by-Step Testing

```bash
cd roles/common

# 1. Create container
molecule create

# 2. Run the role
molecule converge

# 3. Run tests
molecule verify

# 4. Debug if needed
docker exec -it ubuntu-common bash

# 5. Clean up
molecule destroy
```

### Lint Your Code

```bash
make lint
```

## What Gets Tested?

### Common Role
- ✅ Hostname configuration
- ✅ Package installation
- ✅ Directory creation
- ✅ System configuration

### Security Role
- ✅ fail2ban running
- ✅ SSH hardening applied
- ✅ Security packages installed

### Dockge Role
- ✅ Docker service running
- ✅ Dockge container deployed
- ✅ Web interface accessible

### Netdata Role
- ✅ Monitoring stack deployed
- ✅ Netdata accessible on port 19999
- ✅ Health checks configured

## Troubleshooting

### Docker Permission Denied

```bash
# Add yourself to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

### Tests Fail on Port Already in Use

```bash
# Clean up old containers
molecule destroy
docker system prune -f
```

### Python Package Issues

```bash
# Upgrade pip and reinstall
pip install --upgrade pip
pip install -r requirements-test.txt --force-reinstall
```

## Next Steps

- Read the full [Testing Guide](testing.md)
- Add tests for custom roles
- Set up pre-commit hooks
- Review CI/CD pipeline in [.github/workflows/molecule-tests.yml](../.github/workflows/molecule-tests.yml)

## Need Help?

- Check [docs/testing.md](testing.md) for detailed documentation
- Review existing tests in `roles/*/molecule/default/tests/`
- See [Molecule docs](https://molecule.readthedocs.io/)
- See [Testinfra docs](https://testinfra.readthedocs.io/)
