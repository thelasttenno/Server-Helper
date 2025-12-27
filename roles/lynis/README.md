# Lynis Role

Automated security auditing with Lynis security scanner.

## Features

- **Automated Scans**: Weekly security audits (Sunday 3 AM)
- **Report Generation**: Detailed security reports
- **Uptime Kuma Integration**: Push scan results
- **Report Retention**: Configurable retention period (default 90 days)
- **Initial Scan**: Runs scan during setup
- **Comprehensive Auditing**: System hardening, vulnerabilities, compliance

## Requirements

- Ubuntu 24.04 LTS
- Root access for security scanning

## Variables

```yaml
lynis:
  enabled: true
  schedule: "Sun *-*-* 03:00:00"  # Sunday at 3 AM
  scan_dir: "/var/log/lynis"
  retention_days: 90
  uptime_kuma_push_url: "{{ vault_uptime_kuma_push_urls.security }}"
```

## What Lynis Scans

- **Authentication**: Password policies, PAM configuration
- **Boot**: Bootloader configuration, kernel parameters
- **File System**: Permissions, mount options
- **Networking**: Firewall, open ports, network configuration
- **Services**: Running services, unnecessary daemons
- **Software**: Installed packages, updates available
- **SSH**: SSH configuration and security
- **Logging**: Syslog configuration
- **Docker**: Container security (if Docker is installed)

## Scan Schedule

Default schedule: **Weekly on Sunday at 3:00 AM**

Customize in `group_vars/all.yml`:
```yaml
lynis:
  schedule: "Mon *-*-* 02:00:00"  # Monday at 2 AM
  # or
  schedule: "daily"  # Every day at midnight
```

## Manual Scan

```bash
# Run manual scan
sudo /usr/local/bin/lynis-scan.sh

# View latest report
sudo lynis show report

# View specific report
sudo cat /var/log/lynis/lynis-report-latest.txt

# View scan logs
journalctl -u lynis-scan -f
```

## Understanding Reports

### Hardening Index
Score out of 100 indicating system hardening level:
- **90-100**: Excellent
- **80-89**: Good
- **70-79**: Fair
- **Below 70**: Needs improvement

### Warnings
Critical issues requiring immediate attention.

### Suggestions
Recommendations for improving security.

## Report Locations

- **Latest Report**: `/var/log/lynis/lynis-report-latest.txt`
- **All Reports**: `/var/log/lynis/lynis-report-*.txt`
- **Summaries**: `/var/log/lynis/lynis-summary-*.txt`

## Uptime Kuma Integration

Scan results are pushed to Uptime Kuma:

- **Status UP**: No warnings or less than 5 warnings
- **Status DOWN**: 5 or more warnings detected

Message includes:
- Hardening index
- Warning count
- Suggestion count

## Timer Management

```bash
# Check timer status
systemctl status lynis-scan.timer

# View next scheduled run
systemctl list-timers lynis-scan.timer

# Enable/disable timer
sudo systemctl enable lynis-scan.timer
sudo systemctl disable lynis-scan.timer

# Start/stop timer
sudo systemctl start lynis-scan.timer
sudo systemctl stop lynis-scan.timer

# Trigger immediate scan
sudo systemctl start lynis-scan.service
```

## Common Issues Found

### High Priority
- Weak SSH configuration
- No firewall configured
- Services running as root
- Unencrypted file systems
- Missing security updates

### Medium Priority
- Weak password policies
- Unnecessary services enabled
- Missing file integrity checking
- No intrusion detection

## Remediation

After reviewing scan report:

### 1. Review Warnings
```bash
sudo lynis show report | grep warning
```

### 2. Apply Suggestions
```bash
sudo lynis show report | grep suggestion
```

### 3. Use Security Role
Many issues can be fixed with:
```bash
ansible-playbook playbooks/security.yml
```

### 4. Manual Fixes
Follow Lynis suggestions for remaining issues.

### 5. Re-scan
```bash
sudo /usr/local/bin/lynis-scan.sh
```

## Report Cleanup

Old reports are automatically deleted after `retention_days` (default 90 days).

Manual cleanup:
```bash
# Delete reports older than 30 days
find /var/log/lynis -name "lynis-report-*.txt" -mtime +30 -delete

# Delete all reports
sudo rm -f /var/log/lynis/lynis-report-*.txt
```

## Compliance Scanning

Lynis supports compliance frameworks:
- PCI-DSS
- HIPAA
- ISO 27001
- NIST

View compliance status:
```bash
sudo lynis show report | grep compliance
```

## Advanced Usage

### Custom Profiles

Create custom scan profile:
```bash
sudo nano /etc/lynis/custom.prf
```

Use in scan:
```bash
sudo lynis audit system --profile /etc/lynis/custom.prf
```

### Specific Tests

Run only specific tests:
```bash
# Only authentication tests
sudo lynis audit system --tests AUTH

# Only network tests
sudo lynis audit system --tests NETW
```

### Quiet Mode

Suppress output:
```bash
sudo lynis audit system --quiet --quick
```

## Troubleshooting

```bash
# Check Lynis version
lynis --version

# Check Lynis status
lynis show version

# Verify timer is active
systemctl is-active lynis-scan.timer

# Check last scan results
sudo cat /var/log/lynis/lynis-summary-latest.txt

# View scan service logs
journalctl -u lynis-scan.service -n 50
```

## Security Considerations

- Lynis requires root access to perform comprehensive scans
- Reports contain sensitive system information
- Reports are stored with restricted permissions (root only)
- Scan directory is excluded from backups (contains sensitive data)

## Usage

Included automatically in `playbooks/setup.yml`.

Manual run:
```bash
ansible-playbook playbooks/setup.yml --tags lynis
```

## Resources

- **Official Site**: https://cisofy.com/lynis/
- **Documentation**: https://cisofy.com/documentation/lynis/
- **Community**: https://github.com/CISOfy/lynis
- **Controls**: https://cisofy.com/lynis/controls/

## Example Output

```
Hardening Index: 78/100
Warnings: 3
Suggestions: 12

Top Issues:
  - SSH PermitRootLogin is enabled
  - No firewall active
  - Password policy is weak

Report Location: /var/log/lynis/lynis-report-20251223_030000.txt
```
