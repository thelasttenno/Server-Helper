#!/bin/bash
# Interactive Menu Module - Enhanced with Config Backup Options

show_menu() {
    debug "[show_menu] Displaying interactive menu"
    while true; do
        clear
        echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  Server Helper - v0.2.2 Debug Edition ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo "📋 Configuration: 1-Edit 2-Show 3-Validate"
        echo "🚀 Setup: 4-Full 5-Monitor"
        echo "⚙️  Service: 6-Enable 7-Disable 8-Start 9-Stop 10-Restart 11-Status 12-Logs"
        echo "💾 Backup: 13-Dockge 14-Config 15-All 16-Restore-Dockge 17-Restore-Config 18-List"
        echo "💿 NAS: 19-List 20-Mount"
        echo "🖥️  System: 21-Hostname 22-Clean 23-DiskSpace"
        echo "🔄 Updates: 24-Update 25-FullUpgrade 26-Check 27-Status 28-Reboot"
        echo "🔒 Security: 29-Audit 30-Status 31-Harden 32-fail2ban 33-UFW 34-SSH"
        echo "🗑️  Other: 35-Uninstall"
        echo ""
        echo -e "${GREEN}0) Exit${NC}"
        echo ""
        read -p "Choice [0-35]: " c
        
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
            21) read -p "New hostname: " h; set_hostname "$h"; read -p "Press Enter..." ;;
            22) clean_disk; read -p "Press Enter..." ;;
            23) show_disk_space; read -p "Press Enter..." ;;
            24) update_system; read -p "Press Enter..." ;;
            25) full_upgrade ;;
            26) check_updates; show_update_status; read -p "Press Enter..." ;;
            27) show_update_status; read -p "Press Enter..." ;;
            28) read -p "Reboot time [${REBOOT_TIME}]: " t; schedule_reboot "${t:-$REBOOT_TIME}"; read -p "Press Enter..." ;;
            29) security_audit; read -p "Press Enter..." ;;
            30) show_security_status; read -p "Press Enter..." ;;
            31) apply_security_hardening; read -p "Press Enter..." ;;
            32) setup_fail2ban; read -p "Press Enter..." ;;
            33) setup_ufw; read -p "Press Enter..." ;;
            34) harden_ssh; read -p "Press Enter..." ;;
            35) uninstall_server_helper; exit 0 ;;
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
    
    if [ -n "$NEW_HOSTNAME" ]; then
        debug "[main_setup] Setting new hostname: $NEW_HOSTNAME"
        set_hostname "$NEW_HOSTNAME"
    fi
    
    if ! mount_nas && [ "$NAS_MOUNT_REQUIRED" = "true" ]; then
        error "NAS required but failed"
        return 1
    fi
    
    install_docker
    install_dockge
    start_dockge
    
    # Create initial config backup after setup
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
