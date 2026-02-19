# Host Variables

Place per-host override files here, named `{hostname}.yml`.

## Usage

Each file overrides variables for a specific host defined in `inventory/hosts.yml`.

### Example: Custom timezone and backup paths

```yaml
# host_vars/server1.yml
target_timezone: "Europe/London"

target_restic:
  backup_paths:
    - "/opt/stacks"
    - "/etc"
    - "/home/admin/data"
```

### Example: LXC container skip flags

```yaml
# host_vars/lxc-container.yml
lvm_skip: true
swap_skip: true
qemu_agent_skip: true
```

### Example: Custom Netdata alarm thresholds

```yaml
# host_vars/high-load-server.yml
target_netdata:
  alarms:
    cpu_warning: 90
    cpu_critical: 98
    ram_warning: 90
    ram_critical: 98
```

## Precedence

Host vars override group vars (`all.yml`, `control.yml`, `targets.yml`).
See [Ansible Variable Precedence](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#variable-precedence-where-should-i-put-a-variable).
