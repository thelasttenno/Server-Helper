# Troubleshooting Guide

Common issues and solutions for Server Helper.

## Table of Contents

1. [Connectivity Issues](#connectivity-issues)
2. [Ansible Errors](#ansible-errors)
3. [Docker Issues](#docker-issues)
4. [Service-Specific Issues](#service-specific-issues)
5. [Performance Issues](#performance-issues)
6. [Recovery Procedures](#recovery-procedures)

---

## Connectivity Issues

### SSH Connection Refused

**Symptoms:**
```
ssh: connect to host 192.168.1.x port 22: Connection refused
```

**Solutions:**

1. **Check if SSH is running:**
   ```bash
   # On target (via console)
   sudo systemctl status sshd
   sudo systemctl start sshd
   ```

2. **Check firewall:**
   ```bash
   sudo ufw status
   sudo ufw allow 22/tcp
   ```

3. **Check if port is listening:**
   ```bash
   sudo ss -tlnp | grep 22
   ```

---

### SSH Permission Denied

**Symptoms:**
```
Permission denied (publickey)
```

**Solutions:**

1. **Verify SSH key:**
   ```bash
   ssh -vvv user@target  # Verbose output
   ```

2. **Check key permissions:**
   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/id_ed25519
   chmod 644 ~/.ssh/id_ed25519.pub
   ```

3. **Check authorized_keys on target:**
   ```bash
   # On target
   cat ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

4. **Check sshd config:**
   ```bash
   # On target
   sudo grep -i pubkey /etc/ssh/sshd_config
   ```

---

### Ansible Can't Reach Hosts

**Symptoms:**
```
UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh"}
```

**Solutions:**

1. **Test connectivity manually:**
   ```bash
   ssh ansible@192.168.1.x
   ```

2. **Check inventory:**
   ```bash
   ansible-inventory --list
   ansible all -m ping
   ```

3. **Verify ansible.cfg:**
   ```bash
   ansible --version  # Shows config file location
   ```

4. **Run with verbose output:**
   ```bash
   ansible all -m ping -vvvv
   ```

---

## Ansible Errors

### Vault Password Error

**Symptoms:**
```
ERROR! Attempting to decrypt but no vault secrets found
```

**Solutions:**

1. **Check vault password file:**
   ```bash
   ls -la .vault_password
   cat .vault_password  # Verify not empty
   ```

2. **Set environment variable:**
   ```bash
   export ANSIBLE_VAULT_PASSWORD_FILE=.vault_password
   ```

3. **Run with password file:**
   ```bash
   ansible-playbook site.yml --vault-password-file=.vault_password
   ```

---

### Module Not Found

**Symptoms:**
```
ERROR! couldn't resolve module/action 'community.docker.docker_compose_v2'
```

**Solutions:**

1. **Install requirements:**
   ```bash
   ansible-galaxy install -r requirements.yml --force
   ```

2. **Check collections:**
   ```bash
   ansible-galaxy collection list
   ```

---

### Variable Undefined

**Symptoms:**
```
FAILED! => {"msg": "'control_node_ip' is undefined"}
```

**Solutions:**

1. **Check group_vars/all.yml:**
   ```bash
   grep control_node_ip group_vars/all.yml
   ```

2. **Verify vault is decrypted:**
   ```bash
   ansible-vault view group_vars/vault.yml
   ```

---

## Docker Issues

### Docker Daemon Not Running

**Symptoms:**
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Solutions:**

1. **Start Docker:**
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

2. **Check status:**
   ```bash
   sudo systemctl status docker
   sudo journalctl -u docker -n 50
   ```

3. **Check user group:**
   ```bash
   groups  # Should include 'docker'
   sudo usermod -aG docker $USER
   # Log out and back in
   ```

---

### Container Won't Start

**Symptoms:**
Container exits immediately or won't start.

**Solutions:**

1. **Check logs:**
   ```bash
   docker logs <container_name>
   docker logs --tail 100 <container_name>
   ```

2. **Check compose file:**
   ```bash
   cd /opt/stacks/<service>
   docker compose config  # Validate
   ```

3. **Try manual start:**
   ```bash
   docker compose up  # Without -d for interactive
   ```

4. **Check resources:**
   ```bash
   docker system df
   df -h
   free -m
   ```

---

### Port Already in Use

**Symptoms:**
```
Error starting userland proxy: listen tcp4 0.0.0.0:80: bind: address already in use
```

**Solutions:**

1. **Find what's using the port:**
   ```bash
   sudo ss -tlnp | grep :80
   sudo lsof -i :80
   ```

2. **Stop conflicting service:**
   ```bash
   sudo systemctl stop apache2
   sudo systemctl disable apache2
   ```

---

## Service-Specific Issues

### Traefik Not Getting Certificates

**Symptoms:**
- Browser shows certificate warnings
- acme.json is empty

**Solutions:**

1. **Check ACME logs:**
   ```bash
   docker logs traefik 2>&1 | grep -i acme
   ```

2. **Verify DNS:**
   ```bash
   dig +short grafana.example.com
   ```

3. **Check rate limits:**
   Let's Encrypt has rate limits. Use staging first:
   ```yaml
   traefik_acme_ca_server: "https://acme-staging-v02.api.letsencrypt.org/directory"
   ```

4. **Check acme.json permissions:**
   ```bash
   ls -la /opt/stacks/traefik/letsencrypt/acme.json
   # Should be 600
   ```

---

### Netdata Not Streaming

**Symptoms:**
- Child node not showing in parent
- No metrics from targets

**Solutions:**

1. **Check stream.conf on child:**
   ```bash
   docker exec netdata cat /etc/netdata/stream.conf
   ```

2. **Verify API key matches:**
   ```bash
   # On child
   grep "api key" /opt/stacks/netdata/config/stream.conf
   # On parent
   grep -A5 "\[stream\]" /opt/stacks/netdata/config/stream.conf
   ```

3. **Test connectivity:**
   ```bash
   # From child
   curl -v http://<control_ip>:19999/api/v1/info
   ```

4. **Check firewall:**
   ```bash
   # On control
   sudo ufw status | grep 19999
   ```

---

### Loki Not Receiving Logs

**Symptoms:**
- No logs in Grafana Explore
- Promtail errors

**Solutions:**

1. **Check Promtail logs:**
   ```bash
   docker logs promtail
   ```

2. **Verify Loki URL:**
   ```bash
   grep loki /opt/stacks/promtail/promtail-config.yml
   ```

3. **Test Loki endpoint:**
   ```bash
   curl http://<control_ip>:3100/ready
   ```

4. **Check Loki logs:**
   ```bash
   docker logs loki
   ```

---

### Authentik Login Failed

**Symptoms:**
- Can't login to Authentik
- OAuth not working

**Solutions:**

1. **Reset admin password:**
   ```bash
   docker exec -it authentik-server ak create_admin_user
   ```

2. **Check database:**
   ```bash
   docker logs authentik-postgres
   ```

3. **Verify bootstrap credentials:**
   ```bash
   ansible-vault view group_vars/vault.yml | grep authentik
   ```

---

## Performance Issues

### High CPU/Memory Usage

**Solutions:**

1. **Identify culprit:**
   ```bash
   docker stats
   htop
   ```

2. **Check container limits:**
   ```yaml
   # In compose.yaml
   deploy:
     resources:
       limits:
         memory: 512m
   ```

3. **Review Netdata:**
   Access https://netdata.example.com for detailed metrics.

---

### Slow Ansible Execution

**Solutions:**

1. **Enable pipelining:**
   ```ini
   # ansible.cfg
   [ssh_connection]
   pipelining = True
   ```

2. **Use fact caching:**
   ```ini
   [defaults]
   gathering = smart
   fact_caching = jsonfile
   fact_caching_connection = /tmp/ansible_facts
   ```

3. **Run specific tags:**
   ```bash
   ansible-playbook site.yml --tags "grafana"
   ```

---

## Recovery Procedures

### Restore from Backup

```bash
# List available snapshots
source /opt/restic/restic.env
restic snapshots

# Restore specific snapshot
restic restore <snapshot-id> --target /tmp/restore

# Restore specific path
restic restore <snapshot-id> --target /tmp/restore --include "/opt/stacks/grafana"
```

### Rebuild Single Service

```bash
# Stop and remove
cd /opt/stacks/<service>
docker compose down -v

# Redeploy
ansible-playbook playbooks/control.yml --tags "<service>"
```

### Full Control Node Rebuild

```bash
# On new control node
git clone <repo>
cd server-helper

# Restore vault and inventory from backup
cp /backup/group_vars/vault.yml group_vars/
cp /backup/inventory/hosts.yml inventory/

# Redeploy
ansible-playbook playbooks/control.yml
```

### Emergency Access

If locked out:

1. **Console access** (Proxmox, VMware, etc.)
2. **Boot rescue mode**
3. **Mount and fix SSH:**
   ```bash
   mount /dev/sda1 /mnt
   vi /mnt/etc/ssh/sshd_config.d/99-server-helper.conf
   # Temporarily enable PasswordAuthentication
   ```

---

## Validation Commands

```bash
# Full fleet validation
./scripts/validate-fleet.sh

# Quick connectivity test
./scripts/validate-fleet.sh --quick

# Control services only
./scripts/validate-fleet.sh --services

# Ansible ping
ansible all -m ping

# Check specific service
curl -s http://localhost:3000/api/health | jq
```

---

## Getting Help

1. **Check logs first** - Most issues have clear log messages
2. **Run validation** - `./scripts/validate-fleet.sh`
3. **Search issues** - Check GitHub issues
4. **Verbose mode** - Add `-vvvv` to Ansible commands

---

## Next Steps

- [Installation Guide](01-installation.md) - Reinstallation if needed
- [Security Guide](05-security.md) - Security-related issues
