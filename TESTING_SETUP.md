# Testing Setup Summary

This document summarizes the automated testing infrastructure added to Server-Helper.

## What Was Added

### 1. Test Framework Setup

**File**: [requirements-test.txt](requirements-test.txt)
- Molecule 6.0.0+ for role testing
- Testinfra 10.0.0+ for infrastructure validation
- pytest for test execution
- ansible-lint and yamllint for code quality

### 2. Molecule Configurations

Molecule test suites were created for 4 core roles:

#### Common Role
**Location**: [roles/common/molecule/default/](roles/common/molecule/default/)
- Tests system setup and configuration
- Validates package installation
- Checks directory creation
- Verifies logrotate configuration

#### Security Role
**Location**: [roles/security/molecule/default/](roles/security/molecule/default/)
- Tests fail2ban installation and service
- Validates SSH hardening configuration
- Checks security package installation
- Requires Galaxy role dependencies

#### Dockge Role
**Location**: [roles/dockge/molecule/default/](roles/dockge/molecule/default/)
- Tests Docker service running
- Validates Dockge container deployment
- Checks port 5001 listening
- Verifies directory structure

#### Netdata Role
**Location**: [roles/netdata/molecule/default/](roles/netdata/molecule/default/)
- Tests Netdata container deployment
- Validates monitoring stack
- Checks port 19999 listening
- Verifies health check scripts

### 3. Testinfra Test Files

Each role includes Python-based Testinfra tests in `molecule/default/tests/test_default.py`:

**Test patterns include:**
- Service status validation
- File existence and permissions
- Package installation checks
- Port listening verification
- Container deployment validation
- Configuration file content checks

### 4. CI/CD Pipeline

**File**: [.github/workflows/molecule-tests.yml](.github/workflows/molecule-tests.yml)

**Three test jobs:**

1. **test-roles**: Runs Molecule tests for all roles in parallel
2. **lint**: Runs ansible-lint and yamllint
3. **test-playbooks**: Validates playbook syntax

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests
- Manual workflow dispatch

### 5. Helper Scripts

**Test execution scripts** in [scripts/](scripts/):

- **test-all-roles.sh**: Run all Molecule tests sequentially
- **test-single-role.sh**: Test a specific role with custom commands

**Features:**
- Color-coded output
- Dependency checking
- Galaxy role installation
- Summary reporting
- Error tracking

### 6. Makefile

**File**: [Makefile](Makefile)

**Targets:**
```bash
make install-test-deps  # Install testing tools
make test              # Run all tests
make test-all          # Alias for test
make test-role ROLE=<name> [CMD=<cmd>]  # Test specific role
make lint              # Run linters
make syntax-check      # Check playbook syntax
make clean             # Clean test artifacts
```

### 7. Documentation

**Quick Start**: [docs/testing-quickstart.md](docs/testing-quickstart.md)
- 5-minute setup guide
- Common commands
- Troubleshooting tips
- Next steps

**Comprehensive Guide**: [docs/testing.md](docs/testing.md)
- Detailed test documentation
- Writing new tests
- Test patterns
- CI/CD integration
- Debugging techniques

### 8. Linting Configuration

**File**: [.yamllint](.yamllint)
- YAML linting rules
- Line length limits
- Comment formatting
- Truthy value standards

## File Structure

```
Server-Helper/
├── .github/
│   └── workflows/
│       └── molecule-tests.yml      # CI/CD pipeline
├── docs/
│   ├── testing-quickstart.md      # Quick start guide
│   └── testing.md                 # Complete guide
├── roles/
│   ├── common/
│   │   └── molecule/
│   │       └── default/
│   │           ├── molecule.yml
│   │           ├── converge.yml
│   │           ├── verify.yml
│   │           └── tests/
│   │               └── test_default.py
│   ├── security/
│   │   └── molecule/
│   │       └── default/
│   │           ├── molecule.yml
│   │           ├── converge.yml
│   │           ├── requirements.yml
│   │           └── tests/
│   │               └── test_default.py
│   ├── dockge/
│   │   └── molecule/
│   │       └── default/
│   │           ├── molecule.yml
│   │           ├── converge.yml
│   │           └── tests/
│   │               └── test_default.py
│   └── netdata/
│       └── molecule/
│           └── default/
│               ├── molecule.yml
│               ├── converge.yml
│               └── tests/
│                   └── test_default.py
├── scripts/
│   ├── test-all-roles.sh          # Run all tests
│   └── test-single-role.sh        # Run single test
├── requirements-test.txt          # Test dependencies
├── Makefile                       # Test commands
├── .yamllint                      # YAML lint config
└── TESTING_SETUP.md              # This file
```

## How to Use

### First Time Setup

```bash
# 1. Install test dependencies
pip install -r requirements-test.txt

# 2. Ensure Docker is running
docker --version

# 3. Run all tests
make test

# Or test individual role
make test-role ROLE=common
```

### During Development

```bash
# Before committing changes
make lint                          # Check code quality
make syntax-check                  # Validate playbooks
make test-role ROLE=<changed-role> # Test your changes

# Debug a failing test
cd roles/<role>
molecule converge                  # Deploy the role
molecule verify                    # Run tests
docker exec -it <container> bash   # Inspect container
molecule destroy                   # Clean up
```

### In CI/CD

Tests run automatically when you:
1. Push to `main` or `develop`
2. Create a pull request
3. Manually trigger the workflow

View results in GitHub Actions tab.

## What Gets Tested

### Common Role Tests
- ✅ Hostname configuration
- ✅ Package installation (curl, wget, git, vim, htop, etc.)
- ✅ Directory creation (/opt/backups, /opt/scripts, /var/log/server-helper)
- ✅ Logrotate configuration
- ✅ /etc/hosts updated

### Security Role Tests
- ✅ fail2ban installed and running
- ✅ SSH hardening configuration exists
- ✅ Security packages installed
- ✅ SSH service running on port 22

### Dockge Role Tests
- ✅ Dockge directories created
- ✅ Docker service running
- ✅ Dockge container deployed
- ✅ Port 5001 listening
- ✅ docker-compose.yml exists

### Netdata Role Tests
- ✅ Netdata directories created
- ✅ Docker service running
- ✅ Netdata container deployed
- ✅ Port 19999 listening
- ✅ Health check script deployed

## Benefits

1. **Early Bug Detection**: Catch configuration errors before deployment
2. **Regression Prevention**: Ensure changes don't break existing functionality
3. **Documentation**: Tests serve as executable documentation
4. **Confidence**: Deploy with confidence knowing tests passed
5. **Faster Debugging**: Isolated test environments make debugging easier
6. **CI/CD Integration**: Automated testing on every change

## Next Steps

### Add Tests for More Roles

To add tests for other roles (backups, uptime-kuma, etc.):

1. Create `roles/<role>/molecule/default/` directory
2. Copy configuration from an existing role
3. Customize for the role's services
4. Write Testinfra tests
5. Add to CI/CD matrix in `.github/workflows/molecule-tests.yml`

### Extend Existing Tests

- Add more test cases to `test_default.py`
- Test additional scenarios
- Add integration tests
- Test failure scenarios

### Documentation

- Update [docs/testing.md](docs/testing.md) with new patterns
- Document custom test scenarios
- Add troubleshooting tips

## Resources

- **Molecule**: https://molecule.readthedocs.io/
- **Testinfra**: https://testinfra.readthedocs.io/
- **Ansible Best Practices**: https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html
- **Docker for Testing**: https://docs.docker.com/

## Support

If you encounter issues with testing:

1. Check [docs/testing.md](docs/testing.md) for detailed documentation
2. Review existing tests for examples
3. Open an issue on GitHub
4. Check Molecule/Testinfra documentation

---

**Testing infrastructure added**: 2025-12-27
**Roles with tests**: common, security, dockge, netdata
**CI/CD**: GitHub Actions
**Framework**: Molecule + Testinfra
