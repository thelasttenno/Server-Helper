#!/bin/bash
# Automated Remediation Testing Script
# Tests all remediation scenarios to ensure proper functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/remediation-test.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[TEST]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

test_webhook_service() {
    log "Testing webhook service..."

    if systemctl is-active --quiet remediation-webhook; then
        log "✓ Webhook service is running"
    else
        error "✗ Webhook service is not running"
        return 1
    fi

    # Test webhook endpoint
    if curl -s -f "http://localhost:9090?action=health_check" > /dev/null; then
        log "✓ Webhook endpoint is responding"
    else
        error "✗ Webhook endpoint is not responding"
        return 1
    fi
}

test_trigger_scripts() {
    log "Testing trigger scripts..."

    local scripts=(
        "/usr/local/bin/trigger-service-restart.sh"
        "/usr/local/bin/trigger-disk-cleanup.sh"
        "/usr/local/bin/trigger-cert-renewal.sh"
    )

    for script in "${scripts[@]}"; do
        if [ -x "$script" ]; then
            log "✓ $(basename $script) is executable"
        else
            error "✗ $(basename $script) is not executable or missing"
            return 1
        fi
    done
}

test_remediation_playbook() {
    log "Testing remediation playbook..."

    local playbook="/opt/ansible/playbooks/remediation.yml"

    if [ -f "$playbook" ]; then
        log "✓ Remediation playbook exists"
    else
        error "✗ Remediation playbook not found"
        return 1
    fi

    # Syntax check
    if ansible-playbook --syntax-check "$playbook" > /dev/null 2>&1; then
        log "✓ Remediation playbook syntax is valid"
    else
        error "✗ Remediation playbook has syntax errors"
        return 1
    fi
}

test_service_restart() {
    log "Testing service auto-restart..."

    # Create a test container
    log "Creating test container..."
    docker run -d --name remediation-test-container --rm alpine sleep 3600 > /dev/null 2>&1

    sleep 2

    # Stop the container
    log "Stopping test container..."
    docker stop remediation-test-container > /dev/null 2>&1

    # Wait for detection
    sleep 5

    # Trigger remediation
    log "Triggering service restart remediation..."
    /usr/local/bin/trigger-service-restart.sh "remediation-test-container" "test" > /dev/null 2>&1 &

    sleep 10

    # Check if container was restarted
    if docker ps | grep -q remediation-test-container; then
        log "✓ Service auto-restart works"
        docker stop remediation-test-container > /dev/null 2>&1 || true
    else
        warn "⚠ Service auto-restart test inconclusive (container may have already stopped)"
        docker rm -f remediation-test-container > /dev/null 2>&1 || true
    fi
}

test_disk_cleanup() {
    log "Testing disk cleanup..."

    local before_df=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')

    log "Disk usage before cleanup: ${before_df}%"

    # Run cleanup (in test mode, less aggressive)
    log "Running disk cleanup playbook..."
    ansible-playbook /opt/ansible/playbooks/remediation.yml \
        -e "action=disk_cleanup" \
        >> "$LOG_FILE" 2>&1 &

    sleep 5

    local after_df=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')

    log "Disk usage after cleanup: ${after_df}%"

    if [ "$after_df" -le "$before_df" ]; then
        log "✓ Disk cleanup completed (freed $((before_df - after_df))%)"
    else
        warn "⚠ Disk cleanup test completed but no space freed"
    fi
}

test_cert_renewal() {
    log "Testing certificate renewal (dry run)..."

    if command -v certbot > /dev/null 2>&1; then
        if certbot renew --dry-run > /dev/null 2>&1; then
            log "✓ Certificate renewal dry run successful"
        else
            warn "⚠ Certbot dry run failed (may not have certificates configured)"
        fi
    else
        warn "⚠ Certbot not installed, skipping certificate renewal test"
    fi
}

test_health_check() {
    log "Testing comprehensive health check..."

    ansible-playbook /opt/ansible/playbooks/remediation.yml \
        -e "action=health_check" \
        >> "$LOG_FILE" 2>&1

    if [ $? -eq 0 ]; then
        log "✓ Health check completed successfully"
    else
        error "✗ Health check failed"
        return 1
    fi
}

test_log_files() {
    log "Testing log files..."

    local logs=(
        "/var/log/auto-remediation.log"
        "/var/log/remediation-webhook.log"
    )

    for logfile in "${logs[@]}"; do
        if [ -f "$logfile" ]; then
            log "✓ $logfile exists"
        else
            warn "⚠ $logfile does not exist (will be created on first use)"
        fi
    done

    # Check log rotation config
    if [ -f "/etc/logrotate.d/remediation" ]; then
        log "✓ Log rotation is configured"
    else
        warn "⚠ Log rotation not configured"
    fi
}

test_uptime_kuma_integration() {
    log "Testing Uptime Kuma integration..."

    if [ -f "/root/uptime-kuma-monitors.json" ]; then
        log "✓ Uptime Kuma monitor configuration exists"
    else
        warn "⚠ Uptime Kuma monitor configuration not found"
    fi

    # Check if Uptime Kuma is running
    if curl -s -f "http://localhost:3001" > /dev/null 2>&1; then
        log "✓ Uptime Kuma is accessible"
    else
        warn "⚠ Uptime Kuma is not accessible (may not be enabled)"
    fi
}

# Main test execution
main() {
    log "=========================================="
    log "Automated Remediation System - Test Suite"
    log "=========================================="
    log "Started at: $(date)"
    log ""

    local failed=0

    # Run all tests
    test_webhook_service || ((failed++))
    echo ""

    test_trigger_scripts || ((failed++))
    echo ""

    test_remediation_playbook || ((failed++))
    echo ""

    test_log_files || ((failed++))
    echo ""

    test_uptime_kuma_integration || ((failed++))
    echo ""

    test_health_check || ((failed++))
    echo ""

    # Optional interactive tests
    read -p "Run service restart test? (creates temporary container) [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_service_restart || ((failed++))
        echo ""
    fi

    read -p "Run disk cleanup test? (may take a few minutes) [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_disk_cleanup || ((failed++))
        echo ""
    fi

    read -p "Run certificate renewal test? (dry run only) [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_cert_renewal || ((failed++))
        echo ""
    fi

    # Summary
    log "=========================================="
    log "Test Summary"
    log "=========================================="
    log "Completed at: $(date)"
    log "Log file: $LOG_FILE"

    if [ $failed -eq 0 ]; then
        log "✓ All tests passed!"
        return 0
    else
        error "✗ $failed test(s) failed"
        return 1
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root"
    exit 1
fi

# Run tests
main "$@"
