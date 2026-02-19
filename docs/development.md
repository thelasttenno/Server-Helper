# Development

## Project Structure

```
├── ansible.cfg                 # Ansible configuration
├── Makefile                    # 40+ automation targets
├── VERSION                     # Semver (2.0.0)
├── requirements.yml            # Galaxy dependencies
├── group_vars/                 # Variable hierarchy
├── host_vars/                  # Per-host overrides
├── inventory/                  # Host inventory
├── playbooks/                  # 8 orchestration playbooks
├── roles/                      # 20 Ansible roles
│   └── {role}/
│       ├── defaults/main.yml
│       ├── tasks/main.yml
│       ├── meta/main.yml
│       ├── templates/
│       ├── handlers/main.yml
│       └── molecule/default/
├── scripts/
│   ├── setup.sh                # Interactive CLI
│   └── lib/                    # 10 library modules
├── docs/                       # Documentation (this folder)
└── .github/                    # CI/CD workflows
```

## Script Library

`setup.sh` is the main entry point. It sources modules from `scripts/lib/` using strict sourcing — if a required library is missing, it exits with `FATAL`.

### Source Order (matters)

1. **`security.sh`** — Must be sourced first. Registers cleanup trap (unsets sensitive env vars on exit). Provides secure tmpdir selection (RAM disk preferred), vault password file permission enforcement.
2. **`ui_utils.sh`** — Colors, headers, `log_exec` (redacts commands containing password/token/vault/secret keywords)
3. Remaining modules in any order

### Module Reference

| Module | Purpose |
|--------|---------|
| `config_mgr.sh` | YAML read/write, auto-detect IP/timezone/user/domain, quick setup wizard |
| `secrets_mgr.sh` | Generate secure passwords, interactive prompts, vault generation |
| `vault_mgr.sh` | Ansible Vault operations (encrypt/edit/view/rekey), interactive menu |
| `inventory_mgr.sh` | Parse hosts.yml, add/remove hosts, validate inventory |
| `health_check.sh` | SSH, Docker, disk, memory health checks, fleet validation |
| `menu_extras.sh` | Extras menu: add server, open UIs, validate, test, trigger upgrades |
| `testing.sh` | Molecule test runner: test-all, test-role, dependency management |
| `upgrade.sh` | Docker image pull/restart/verify per-service, cleanup, result tracking |

### Design Decisions

- **No standalone wrapper scripts** — All functionality accessed through `setup.sh` menu or `make` targets
- **Idempotent secrets** — Two modes: FRESH (regenerate all) and IDEMPOTENT (preserve existing, generate missing)
- **Secure logging** — `log_exec` automatically redacts commands containing sensitive keywords

## Testing

### Molecule

Every role has a complete Molecule test suite:

```bash
make test                    # All roles
make test-role ROLE=common   # Specific role
```

Test configuration:

- **Driver**: Docker (`geerlingguy/docker-ubuntu2404-ansible`)
- **Container mode**: Privileged with systemd
- **Sequence**: dependency → destroy → syntax → create → prepare → converge → idempotence → verify → destroy
- **Verify**: Ansible-based assertions (file existence, service status, config values)

### Adding Tests for a New Role

Create `roles/{role}/molecule/default/`:

```yaml
# molecule.yml
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-ubuntu2404-ansible
    privileged: true
    command: /lib/systemd/systemd
provisioner:
  name: ansible
verifier:
  name: ansible
```

```yaml
# converge.yml
- hosts: all
  roles:
    - role: your_role
```

```yaml
# verify.yml
- hosts: all
  tasks:
    - name: Check config exists
      ansible.builtin.stat:
        path: /etc/your-config
      register: config_file
    - name: Assert config deployed
      ansible.builtin.assert:
        that: config_file.stat.exists
```

## CI/CD (GitHub Actions)

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `molecule-tests.yml` | Push/PR to main/develop | Runs Molecule on `common`, `security`, `dockge`, `netdata` |
| `changelog-check.yml` | PR to main/develop | Enforces CHANGELOG.md updates |
| `release.yml` | Tag push | Automated release creation |

## Linting

```bash
make lint
```

Runs:

- **ansible-lint** — playbooks and roles
- **yamllint** — all YAML files (config: `.yamllint`)
- **ansible-playbook --syntax-check** — syntax validation (via pre-push hook)

## Pre-Commit Hooks

```bash
# Configure git to use project hooks
git config core.hooksPath .githooks
```

| Hook | Purpose |
|------|---------|
| `.githooks/pre-commit` | Block commits with unencrypted vault |
| `.githooks/pre-push` | Syntax-check all playbooks before push |

Also available via the `pre-commit` framework (`.pre-commit-config.yaml`):

- `trailing-whitespace`, `end-of-file-fixer`, `check-yaml`, `check-added-large-files`
- `ansible-lint`
- `vault-encrypted` (local hook)

## Galaxy Dependencies

```yaml
# requirements.yml
collections:
  - community.docker   >= 3.4.0
  - community.general  >= 8.0.0
  - community.crypto   >= 2.0.0
  - community.postgresql >= 3.0.0
  - ansible.posix      >= 1.5.0
```

Install with:

```bash
make deps
# or: ansible-galaxy install -r requirements.yml
```

## Contributing

1. Create a feature branch from `develop`
2. Make changes, update `CHANGELOG.md`
3. Run `make lint` and `make test-role ROLE=affected_role`
4. Open a PR to `develop`
5. CI will run Molecule tests and changelog check
