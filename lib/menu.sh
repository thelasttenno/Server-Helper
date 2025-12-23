#!/bin/bash
# Interactive Menu Module - Enhanced with Config Backup Options

show_menu() {
    debug "[show_menu] Displaying interactive menu"
    while true; do
        clear
        echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  Server Helper - v0.3.0 Self-Update   ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo "📋 Configuration: 1-Edit 2-Show 3-Validate"
        echo "🚀 Setup: 4-Full 5-Monitor"
        echo "⚙️  Service: 6-Enable 7-Disable 8-Start 9-Stop 10-Restart 11-Status 12-Logs"
        echo "💾 Backup: 13-Dockge 14-Config 15-All 16-Restore-Dockge 17-Restore-Config 18-List"
        echo "💿 NAS: 19-List 20-Mount 21-EmergencyUnmount"
        echo "🖥️  System: 22-Hostname 23-Clean 24-DiskSpace"
        echo "🔄 Updates: 25-Update 26-FullUpgrade 27-Check 28-Status 29-Reboot"
        echo "🔒 Security: 30-Audit 31-Status 32-Harden 33-fail2ban 34-UFW 35-SSH"
        echo "🔧 Install: 36-CheckInstall 37-CleanInstall"
        echo "🆙 Self-Update: 39-CheckUpdate 40-Update 41-Rollback 42-Changelog"
        echo "🗑️  Other: 43-Uninstall"
        echo ""
        echo -e "${GREEN}0) Exit${NC}"
        echo ""
        read -p "Choice [0-43]: " c
        
        debug "[show_menu] User selected: $c"
        
        case $c in
            1) edit_config; read -p "Press Enter..." ;;
            2) show_config; read -p "Press Enter..." ;;
            3) validate_config; read -p "Press Enter..." ;;
            4) main_setup ;;
            5) monitor_services ;;
            6) create_systemd_service; read -p "Press Enter..." ;;
            7) remove_systemd_service; read -p "Press Enter..." ;;
            8) start_service_now; read -p "Press Enter..." ;;
            9) stop_service; read -p "Press Enter..." ;;
            10) restart_service; read -p "Press Enter..." ;;
            11) show_service_status; read -p "Press Enter..." ;;
            12) show_logs ;;
            13) backup_dockge; read -p "Press Enter..." ;;
            14) backup_config_files; read -p "Press Enter..." ;;
            15) backup_all; read -p "Press Enter..." ;;
            16) restore_dockge; read -p "Press Enter..." ;;
            17) restore_config_files; read -p "Press Enter..." ;;
            18) list_backups; read -p "Press Enter..." ;;
            19) list_nas_shares; read -p "Press Enter..." ;;
            20) mount_nas; read -p "Press Enter..." ;;
            21) emergency_unmount_nas; read -p "Press Enter..." ;;
            22) read -p "New hostname: " h; set_hostname "$h"; read -p "Press Enter..." ;;
            23) clean_disk; read -p "Press Enter..." ;;
            24) show_disk_space; read -p "Press Enter..." ;;
            25) update_system; read -p "Press Enter..." ;;
            26) full_upgrade ;;
            27) check_updates; show_update_status; read -p "Press Enter..." ;;
            28) show_update_status; read -p "Press Enter..." ;;
            29) read -p "Reboot time [${REBOOT_TIME}]: " t; schedule_reboot "${t:-$REBOOT_TIME}"; read -p "Press Enter..." ;;
            30) security_audit; read -p "Press Enter..." ;;
            31) show_security_status; read -p "Press Enter..." ;;
            32) apply_security_hardening; read -p "Press Enter..." ;;
            33) setup_fail2ban; read -p "Press Enter..." ;;
            34) setup_ufw; read -p "Press Enter..." ;;
            35) harden_ssh; read -p "Press Enter..." ;;
            36) pre_installation_check; read -p "Press Enter..." ;;
            37)
                detect_existing_service && cleanup_existing_service
                detect_existing_dockge && cleanup_existing_dockge
                detect_existing_mounts && cleanup_existing_mounts
                detect_existing_docker && cleanup_existing_docker
                log "✓ Installation cleanup complete"
                read -p "Press Enter..."
                ;;
            39) check_for_script_updates; read -p "Press Enter..." ;;
            40) self_update; read -p "Press Enter..." ;;
            41) rollback_update; read -p "Press Enter..." ;;
            42) show_update_changelog ;;
            43) uninstall_server_helper; exit 0 ;;
            0) log "Goodbye!"; exit 0 ;;
            *) error "Invalid choice"; sleep 2 ;;
        esac
    done
}

set_hostname() {
    debug "[set_hostname] Setting hostname to: $1"
    [ -z "$1" ] && { error "Hostname required"; return 1; }
    validate_hostname "$1" || { error "Invalid hostname"; return 1; }
    
    sudo hostnamectl set-hostname "$1"
    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$1/g" /etc/hosts
    grep -q "127.0.1.1" /etc/hosts || echo "127.0.1.1	$1" | sudo tee -a /etc/hosts
    log "✓ Hostname set to: $1"
    debug "[set_hostname] Hostname change complete"
}

show_hostname() {
    debug "[show_hostname] Displaying hostname"
    log "Hostname: $(hostname)"
}

main_setup() {
    debug "[main_setup] Starting full setup"
    log "Running full setup..."

    # Run pre-installation check
    debug "[main_setup] Running pre-installation check"
    pre_installation_check

    log ""
    log "Pre-installation check complete. Starting installation..."
    log ""

    if [ -n "$NEW_HOSTNAME" ]; then
        debug "[main_setup] Setting new hostname: $NEW_HOSTNAME"
        log "Setting hostname..."
        set_hostname "$NEW_HOSTNAME"
    fi

    log "Mounting NAS shares..."
    if ! mount_nas && [ "$NAS_MOUNT_REQUIRED" = "true" ]; then
        error "NAS required but failed"
        return 1
    fi

    log ""
    log "Installing Docker..."
    install_docker

    log ""
    log "Installing Dockge..."
    install_dockge

    log ""
    log "Starting Dockge..."
    start_dockge

    # Create initial config backup after setup
    log ""
    log "Creating initial configuration backup..."
    debug "[main_setup] Creating initial config backup"
    backup_config_files

    show_setup_complete
    debug "[main_setup] Full setup complete"
}

show_setup_complete() {
    debug "[show_setup_complete] Displaying setup summary"
    echo ""
    log "═══════════════════════════════════════"
    log "        Setup Complete!"
    log "═══════════════════════════════════════"
    log "Hostname: $(hostname)"
    log "Dockge: http://localhost:$DOCKGE_PORT"
    list_nas_shares
    echo ""
}
