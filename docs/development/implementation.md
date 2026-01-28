# Implementation Guide - Remaining Work

This guide outlines what needs to be implemented to complete Server Helper v1.0.0.

---

## ✅ What's Already Done

- ✅ Project structure
- ✅ Main playbooks (setup, backup, security, update)
- ✅ Core roles: common, nas, dockge, restic
- ✅ All docker-compose stack templates
- ✅ Documentation (README, MIGRATION, CHANGELOG)
- ✅ Configuration system
- ✅ Requirements (Ansible Galaxy + Python)

---

## 🔨 What Needs Implementation

### Priority 1: Essential Roles

#### 1. Netdata Role (`roles/netdata/`)

**Files needed:**
```
roles/netdata/
├── tasks/
│   └── main.yml
└── templates/
    └── netdata-alarms.conf.j2
```

**Implementation:**
```yaml
# roles/netdata/tasks/main.yml
---
# Netdata is deployed via Dockge stack
# This role configures alarms after deployment

- name: Wait for Netdata to be ready
  wait_for:
    host: localhost
    port: "{{ monitoring.netdata.port }}"
    timeout: 60

- name: Configure Netdata alarms
  template:
    src: netdata-alarms.conf.j2
    dest: /opt/dockge/stacks/netdata/health.d/custom-alarms.conf
  when: netdata.alarms.enabled
  notify: restart netdata

- name: Create alarm notification script
  template:
    src: netdata-notify.sh.j2
    dest: /opt/scripts/netdata-notify.sh
    mode: '0755'
  when: netdata.alarms.uptime_kuma_urls is defined
```

**Alarm template:**
```jinja2
# templates/netdata-alarms.conf.j2
# CPU alarm
alarm: cpu_usage_critical
on: system.cpu
lookup: average -3m
warn: $this > {{ netdata.alarms.cpu_warning }}
crit: $this > {{ netdata.alarms.cpu_critical }}
exec: /opt/scripts/netdata-notify.sh cpu

# RAM alarm
alarm: ram_usage_critical
on: system.ram
lookup: average -3m
warn: $this > {{ netdata.alarms.ram_warning }}
crit: $this > {{ netdata.alarms.ram_critical }}
exec: /opt/scripts/netdata-notify.sh ram

# Disk alarm
alarm: disk_usage_critical
on: disk.space
lookup: average -3m
warn: $this > {{ netdata.alarms.disk_warning }}
crit: $this > {{ netdata.alarms.disk_critical }}
exec: /opt/scripts/netdata-notify.sh disk
```

---

#### 2. Uptime Kuma Role (`roles/uptime-kuma/`)

**Files needed:**
```
roles/uptime-kuma/
└── tasks/
    └── main.yml
```

**Implementation:**
```yaml
# roles/uptime-kuma/tasks/main.yml
---
# Uptime Kuma is deployed via Dockge stack
# This role sets up initial configuration

- name: Wait for Uptime Kuma to be ready
  wait_for:
    host: localhost
    port: "{{ uptime_kuma.port }}"
    timeout: 120

- name: Display Uptime Kuma setup instructions
  debug:
    msg: |
      ✓ Uptime Kuma deployed successfully!
      
      🌐 Access: http://{{ ansible_host }}:{{ uptime_kuma.port }}
      
      📋 Initial Setup (Manual):
      1. Create admin account
      2. Add monitors:
         - Netdata: HTTP → http://localhost:19999/api/v1/info
         - Dockge: HTTP → http://localhost:5001
         - Docker: Docker → unix:///var/run/docker.sock
      3. Configure notifications (Settings → Notifications)
      
      💡 Push Monitor URLs (for Netdata, Restic, Lynis):
      - Get from each monitor's settings page
      - Add to group_vars/all.yml:
        - netdata.alarms.uptime_kuma_urls.cpu
        - restic.uptime_kuma_push_url
        - security.lynis_uptime_kuma_push_url

# Note: Uptime Kuma API configuration would go here
# but requires API key from initial setup
# For now, manual setup via UI is recommended
```

---

#### 3. Lynis Role (`roles/lynis/`)

**Files needed:**
```
roles/lynis/
├── tasks/
│   └── main.yml
└── templates/
    ├── lynis-scan.sh.j2
    ├── lynis-scan.service.j2
    └── lynis-scan.timer.j2
```

**Implementation:**
```yaml
# roles/lynis/tasks/main.yml
---
- name: Install Lynis
  apt:
    name: lynis
    state: present

- name: Create Lynis log directory
  file:
    path: /var/log/lynis
    state: directory
    mode: '0700'

- name: Create Lynis scan script
  template:
    src: lynis-scan.sh.j2
    dest: /opt/scripts/lynis-scan.sh
    mode: '0700'

- name: Create Lynis systemd service
  template:
    src: lynis-scan.service.j2
    dest: /etc/systemd/system/lynis-scan.service
    mode: '0644'
  notify: systemd daemon-reload

- name: Create Lynis systemd timer
  template:
    src: lynis-scan.timer.j2
    dest: /etc/systemd/system/lynis-scan.timer
    mode: '0644'
  notify: systemd daemon-reload

- name: Enable and start Lynis timer
  systemd:
    name: lynis-scan.timer
    enabled: yes
    state: started
    daemon_reload: yes

handlers:
  - name: systemd daemon-reload
    systemd:
      daemon_reload: yes
```

**Scan script template:**
```bash
#!/bin/bash
# templates/lynis-scan.sh.j2

LOG_FILE="/var/log/lynis/scan-$(date +%Y%m%d).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Lynis Security Scan - $(date)"
lynis audit system --quick --quiet

# Get scan score
SCORE=$(grep "Hardening index" /var/log/lynis-report.dat | awk '{print $4}')

# Send to Uptime Kuma
{% if security.lynis_uptime_kuma_push_url %}
curl -fsS "{{ security.lynis_uptime_kuma_push_url }}?status=up&msg=score-${SCORE}" || true
{% endif %}

echo "Scan complete. Score: $SCORE"
```

---

#### 4. Security Role (`roles/security/`)

**Files needed:**
```
roles/security/
├── tasks/
│   └── main.yml
└── meta/
    └── main.yml
```

**Implementation:**
```yaml
# roles/security/tasks/main.yml
---
# This role wraps community security roles

- name: Apply base security hardening
  include_role:
    name: geerlingguy.security
  vars:
    security_sudoers_passwordless: []
    security_autoupdate_enabled: "{{ security.unattended_upgrades }}"

- name: Install and configure fail2ban
  include_role:
    name: robertdebock.fail2ban
  when: security.fail2ban_enabled
  vars:
    fail2ban_bantime: "{{ security.fail2ban_bantime }}"
    fail2ban_maxretry: "{{ security.fail2ban_maxretry }}"

- name: Configure UFW firewall
  include_role:
    name: weareinteractive.ufw
  when: security.ufw_enabled
  vars:
    ufw_enabled: yes
    ufw_default_input_policy: deny
    ufw_default_output_policy: allow
    ufw_rules: "{{ security.ufw_allowed_ports | map('regex_replace', '^(.*)$', 'port=\\1 proto=tcp rule=allow') | list }}"

- name: Harden SSH
  block:
    - lineinfile:
        path: /etc/ssh/sshd_config
        regexp: "{{ item.regexp }}"
        line: "{{ item.line }}"
      loop:
        - regexp: '^#?PasswordAuthentication'
          line: 'PasswordAuthentication no'
        - regexp: '^#?PermitRootLogin'
          line: 'PermitRootLogin no'
        - regexp: '^#?MaxAuthTries'
          line: 'MaxAuthTries {{ security.ssh_max_auth_tries }}'
      notify: restart sshd
  when: security.ssh_hardening

handlers:
  - name: restart sshd
    service:
      name: sshd
      state: restarted
```

---

#### 5. Self-Update Role (`roles/self-update/`)

**Files needed:**
```
roles/self-update/
├── tasks/
│   └── main.yml
└── templates/
    ├── ansible-pull.service.j2
    └── ansible-pull.timer.j2
```

**Implementation:**
```yaml
# roles/self-update/tasks/main.yml
---
- name: Create ansible-pull systemd service
  template:
    src: ansible-pull.service.j2
    dest: /etc/systemd/system/ansible-pull.service
    mode: '0644'
  notify: systemd daemon-reload

- name: Create ansible-pull systemd timer
  template:
    src: ansible-pull.timer.j2
    dest: /etc/systemd/system/ansible-pull.timer
    mode: '0644'
  notify: systemd daemon-reload

- name: Enable and start ansible-pull timer
  systemd:
    name: ansible-pull.timer
    enabled: yes
    state: started
    daemon_reload: yes

handlers:
  - name: systemd daemon-reload
    systemd:
      daemon_reload: yes
```

**Service template:**
```ini
# templates/ansible-pull.service.j2
[Unit]
Description=Ansible Pull Service
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/ansible-pull \
  -U {{ self_update.git_repo }} \
  -C {{ self_update.version }} \
  -d /opt/ansible/Server-Helper \
  {{ self_update.playbook }}
StandardOutput=journal
StandardError=journal
```

**Timer template:**
```ini
# templates/ansible-pull.timer.j2
[Unit]
Description=Ansible Pull Timer

[Timer]
OnCalendar={{ self_update.schedule }}
Persistent=true

[Install]
WantedBy=timers.target
```

---

### Priority 2: Optional Roles

#### 6. Watchtower Role (`roles/watchtower/`)

Simple - just document that it's deployed via Dockge stack:

```yaml
# roles/watchtower/tasks/main.yml
---
- name: Watchtower info
  debug:
    msg: |
      Watchtower deployed via Dockge stack
      Stack location: {{ dockge.stacks_dir }}/watchtower
```

---

#### 7. Reverse Proxy Role (`roles/reverse-proxy/`)

Similar - deployed via Dockge:

```yaml
# roles/reverse-proxy/tasks/main.yml
---
- name: Reverse proxy info
  debug:
    msg: |
      {{ reverse_proxy.type | title }} deployed via Dockge stack
      Stack location: {{ dockge.stacks_dir }}/reverse-proxy
```

---

## 📝 Additional Files Needed

### 1. `.gitignore`

```gitignore
# Ansible
*.retry
.ansible/

# Logs
*.log

# Secrets
group_vars/all.yml
inventory/hosts.yml

# Python
__pycache__/
*.py[cod]
*$py.class
.Python
venv/

# OS
.DS_Store
Thumbs.db

# Editor
.vscode/
.idea/
*.swp
*.swo
*~
```

### 2. `VERSION` file

```
1.0.0
```

### 3. `CONTRIBUTING.md`

Basic contribution guidelines for the project.

---

## 🧪 Testing Checklist

### Before Release

- [ ] Test on fresh Ubuntu 24.04 VM
- [ ] Verify all playbooks run successfully
- [ ] Check all services start correctly
- [ ] Test backup creation and restoration
- [ ] Verify monitoring is working
- [ ] Test security audit
- [ ] Verify self-update mechanism
- [ ] Test migration from v0.3.0
- [ ] Check documentation accuracy
- [ ] Verify all links in documentation

### Test Commands

```bash
# Syntax check
ansible-playbook playbooks/setup.yml --syntax-check

# Dry run
ansible-playbook playbooks/setup.yml --check

# Full run
ansible-playbook playbooks/setup.yml -v

# Test specific roles
ansible-playbook playbooks/setup.yml --tags nas
ansible-playbook playbooks/setup.yml --tags dockge
ansible-playbook playbooks/setup.yml --tags restic
```

---

## 📦 Release Checklist

### Before v1.0.0 Release

- [ ] Complete all remaining roles
- [ ] Test on Ubuntu 24.04
- [ ] Update documentation with screenshots
- [ ] Create release notes
- [ ] Tag v1.0.0 in Git
- [ ] Update GitHub repository
- [ ] Create release on GitHub
- [ ] Update README badges
- [ ] Announce on forums/social media

---

## 🎯 Estimated Time to Complete

- **Netdata role**: 2-3 hours
- **Uptime Kuma role**: 1-2 hours
- **Lynis role**: 2-3 hours
- **Security role**: 2-3 hours
- **Self-update role**: 1-2 hours
- **Watchtower role**: 30 minutes
- **Reverse-proxy role**: 30 minutes
- **Additional files**: 1 hour
- **Testing**: 4-6 hours
- **Documentation polish**: 2-3 hours

**Total**: ~15-20 hours of focused work

---

## 💡 Tips for Implementation

1. **Test incrementally**: Implement one role, test it, then move to next
2. **Use check mode**: Always test with `--check` first
3. **Start simple**: Get basic functionality working, then add features
4. **Document as you go**: Update README with any changes
5. **Keep it modular**: Each role should work independently
6. **Use handlers**: For service restarts, use Ansible handlers
7. **Be idempotent**: Roles should be safe to run multiple times
8. **Add tags**: Make it easy to run specific parts

---

## 🚀 Quick Implementation Priority

If you want to get a minimal viable product (MVP) working first:

1. ✅ **Already done**: Dockge, Netdata, Uptime Kuma stacks
2. ⏳ **Must have**: Security role (fail2ban, UFW, SSH)
3. ⏳ **Should have**: Lynis role (security auditing)
4. ⏳ **Nice to have**: Self-update role (ansible-pull)
5. ⏳ **Optional**: Watchtower, Reverse-proxy

This gives you a working system with monitoring, backups, and security in place.

---

**The foundation is solid - now it's time to complete the implementation!** 🎉
