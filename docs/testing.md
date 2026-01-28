# Testing Guide for Server-Helper

This guide covers how to test the Server-Helper playbooks using Molecule and Testinfra.

## Overview

Server-Helper uses **Molecule** for testing Ansible roles in ephemeral Docker containers, and **Testinfra** for infrastructure validation. This catches configuration bugs early before deploying to production.

## Prerequisites

### Local Development

1. **Python 3.11+** installed
2. **Docker** installed and running
3. **Git** for version control

### Install Test Dependencies

```bash
# Install testing tools
pip install -r requirements-test.txt

# Verify installation
molecule --version
ansible --version
docker --version
```

## Running Tests

### Test All Roles

To test all roles at once:

```bash
# From the project root
./scripts/test-all-roles.sh
```

### Test Individual Roles

To test a specific role:

```bash
# Navigate to the role directory
cd roles/common

# Run the full test sequence
molecule test

# Or run tests step-by-step:
molecule create    # Create test container
molecule converge  # Run the role
molecule verify    # Run verification tests
molecule destroy   # Clean up
```

### Test Specific Scenarios

```bash
# Only run Testinfra tests (assumes container exists)
cd roles/common
molecule verify

# Run with verbose output
molecule test --debug

# Keep container running after tests for debugging
molecule converge
molecule verify
# Container stays running - inspect with:
docker exec -it ubuntu-common bash
# Clean up when done:
molecule destroy
```

## Available Role Tests

### Common Role
Tests basic system setup, package installation, and directory creation.

```bash
cd roles/common
molecule test
```

**What it tests:**
- Hostname configuration
- Timezone settings
- Essential package installation (curl, wget, git, vim, htop, etc.)
- Required directories (`/opt/backups`, `/opt/scripts`, `/var/log/server-helper`)
- Logrotate configuration

### Security Role
Tests security hardening, fail2ban, and SSH configuration.

```bash
cd roles/security
molecule test
```

**What it tests:**
- fail2ban installation and service status
- SSH hardening configuration
- Security packages (unattended-upgrades)
- SSH service running on port 22

### Dockge Role
Tests Docker container management interface.

```bash
cd roles/dockge
molecule test
```

**What it tests:**
- Dockge directories creation
- Docker service running
- Dockge container deployment
- Port 5001 listening
- docker-compose.yml configuration

### Netdata Role
Tests monitoring stack deployment.

```bash
cd roles/netdata
molecule test
```

**What it tests:**
- Netdata directories creation
- Docker service running
- Netdata container deployment
- Port 19999 listening
- Health check script deployment

## Writing New Tests

### Molecule Configuration Structure

Each role with tests should have this structure:

```
roles/your-role/
├── molecule/
│   └── default/
│       ├── molecule.yml          # Molecule configuration
│       ├── converge.yml          # Playbook to test the role
│       ├── verify.yml            # Ansible-based verification (optional)
│       ├── requirements.yml      # Galaxy role dependencies (if needed)
│       └── tests/
│           └── test_default.py   # Testinfra tests
├── tasks/
│   └── main.yml
└── ...
```

### Example Testinfra Test

Create `roles/your-role/molecule/default/tests/test_default.py`:

```python
"""
Testinfra tests for your-role
"""
import os
import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_service_running(host):
    """Test that your service is running."""
    service = host.service('your-service')
    assert service.is_running
    assert service.is_enabled


def test_config_file_exists(host):
    """Test that configuration file exists."""
    config = host.file('/etc/your-service/config.yml')
    assert config.exists
    assert config.is_file
    assert config.contains('expected_setting')


def test_port_listening(host):
    """Test that service is listening on correct port."""
    socket = host.socket('tcp://0.0.0.0:8080')
    assert socket.is_listening
```

### Example Molecule Configuration

Create `roles/your-role/molecule/default/molecule.yml`:

```yaml
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: ubuntu-your-role
    image: geerlingguy/docker-ubuntu2204-ansible:latest
    command: ""
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    cgroupns_mode: host
    privileged: true
    pre_build_image: true
provisioner:
  name: ansible
  inventory:
    host_vars:
      ubuntu-your-role:
        your_variable: value
verifier:
  name: testinfra
  options:
    v: 1
```

## Continuous Integration

Tests run automatically on GitHub Actions for:
- Every push to `main` or `develop` branches
- Every pull request
- Manual workflow dispatch

### CI/CD Pipeline

The pipeline includes:

1. **Molecule Tests**: Run full test suite for each role
2. **Ansible Lint**: Check playbooks and roles for best practices
3. **YAML Lint**: Validate YAML syntax
4. **Syntax Check**: Verify playbook syntax

View results at: `https://github.com/your-org/Server-Helper/actions`

## Troubleshooting

### Docker Permission Issues

```bash
# Add your user to docker group
sudo usermod -aG docker $USER
# Log out and back in for changes to take effect
```

### Container Won't Start

```bash
# Check Docker is running
sudo systemctl status docker

# Clean up old containers
molecule destroy
docker system prune -f
```

### Tests Failing Locally But Pass in CI

```bash
# Ensure you're using the same Python version as CI (3.11)
python --version

# Update test dependencies
pip install -r requirements-test.txt --upgrade

# Clear Molecule cache
rm -rf roles/*/molecule/default/.molecule/
```

### Inspecting Failed Tests

```bash
# Run converge without destroying container
molecule converge

# Get container name
docker ps

# Exec into container
docker exec -it <container-name> bash

# Manually test commands
systemctl status your-service
cat /etc/your-service/config

# When done
molecule destroy
```

## Best Practices

1. **Test Early, Test Often**: Run tests before committing
2. **Keep Tests Fast**: Use pre-built Docker images
3. **Test Real Scenarios**: Mirror production configurations
4. **Document Expectations**: Add comments explaining what each test validates
5. **Clean Up**: Always destroy containers after testing

## Common Test Patterns

### Testing Services

```python
def test_service_running(host):
    service = host.service('myservice')
    assert service.is_running
    assert service.is_enabled
```

### Testing Files

```python
def test_config_file(host):
    f = host.file('/etc/myapp/config.yml')
    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
    assert f.mode == 0o644
    assert f.contains('setting: value')
```

### Testing Packages

```python
def test_package_installed(host):
    pkg = host.package('nginx')
    assert pkg.is_installed
```

### Testing Ports

```python
def test_port_listening(host):
    socket = host.socket('tcp://0.0.0.0:80')
    assert socket.is_listening
```

### Testing Commands

```python
def test_command_output(host):
    cmd = host.run('myapp --version')
    assert cmd.rc == 0
    assert 'version 1.2.3' in cmd.stdout
```

## Resources

- [Molecule Documentation](https://molecule.readthedocs.io/)
- [Testinfra Documentation](https://testinfra.readthedocs.io/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Docker SDK for Python](https://docker-py.readthedocs.io/)
