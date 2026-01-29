---
globs: ["roles/**/*", "playbooks/*.yml", "group_vars/*.yml", "host_vars/*.yml", "inventory/*.yml", "scripts/**/*.sh", "setup.sh", "bootstrap-target.sh", "docs/wiki/*.md", "*.md"]
---

# Server Helper v2.0
Ansible infrastructure automation: Docker services, Traefik proxy, Netdata/Grafana/Loki monitoring, security hardening.

stack: [Ansible 2.14+, Docker CE, Ubuntu 24.04, Traefik v3, Authentik, Step-CA, Netdata, Grafana, Loki, Pi-hole, Uptime Kuma, Dockge]

## Architecture
- control_node: Traefik, Grafana, Loki, Authentik, Step-CA, Pi-hole, Uptime Kuma, Netdata (parent)
- target_nodes: Stream metrics/logs to control; run workloads

## Roles by Tier
- tier_1_all: [common, lvm_config, swap, qemu_agent, security, docker, watchtower, restic, dockge]
- tier_2_target: [netdata (child), promtail, docker_socket_proxy]
- tier_3_control: [traefik, authentik, step_ca, pihole, netdata (parent), loki, grafana, uptime_kuma]

## Paths
- entry: setup.sh
- playbooks: playbooks/{site,bootstrap,control,target,add-target,update,backup}.yml
- roles: roles/{name}/{tasks,defaults,templates,handlers}/
- vars: group_vars/{all,control,targets,vault}.yml
- host_vars: host_vars/{hostname}.yml
- inventory: inventory/hosts.yml
- scripts: scripts/vault.sh, scripts/lib/*.sh
- deploy_target: /opt/stacks/{service}/

## Variable Precedence (low→high)
1. group_vars/all.yml - Global: domain, IPs, security, Docker
2. group_vars/control.yml - Control services: Traefik, Grafana, Authentik
3. group_vars/targets.yml - Target services: Netdata child, Promtail, Restic
4. host_vars/{host}.yml - Per-host: timezone, backups, thresholds
5. inventory/hosts.yml inline - Connection: SSH, ports, LXC skip flags

## Naming
- global_vars: target_* (target_domain, target_timezone, target_dns, target_notification_email)
- control_services: control_* (control_traefik, control_grafana)
- secrets: vault_{service}_{secret} or vault_{service}_credentials (nested)
- lxc_flags: {feature}_skip (lvm_skip, swap_skip, qemu_agent_skip)
- docker_paths: /opt/stacks/{service}/
- docker_network: traefik-public

## Commands
- deploy: ansible-playbook playbooks/site.yml
- dry_run: ansible-playbook playbooks/site.yml --check
- tags: ansible-playbook playbooks/site.yml --tags "traefik,security"
- limit: ansible-playbook playbooks/site.yml --limit server-01
- vault: ./scripts/vault.sh {encrypt|decrypt|edit|view}

## Add Role Steps
1. Create roles/{name}/{tasks,defaults}/main.yml
2. Create roles/{name}/templates/compose.yaml.j2 (if Docker)
3. Add to playbooks/{control,target}.yml
4. Add vars to group_vars/{control,targets}.yml
5. Update docs/wiki/04-roles.md, CHANGELOG.md

## Standards
- ansible: Idempotent tasks, defaults in roles/{name}/defaults/main.yml, handlers for restarts
- secrets: vault_ prefix in vault.yml
- docker: JSON logging (10m, 3 files), traefik-public network
- lxc: Requires keyctl=1, nesting=1; set lvm_skip, swap_skip, qemu_agent_skip

## Docs Matrix
- roles_playbooks: [README.md, CHANGELOG.md, docs/wiki/01-installation.md, docs/wiki/04-roles.md]
- variables: [docs/wiki/03-configuration.md, group_vars/*.example.yml]
- architecture: [docs/wiki/02-architecture.md, docs/wiki/07-quick-reference.md]
- security: [docs/wiki/05-security.md]
- changelog_format: Keep a Changelog (Added, Changed, Deprecated, Removed, Fixed, Security, Documentation)
