#!/bin/bash
# Interactive Menu Module

show_menu() {
    while true; do
        clear
        echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║    Server Helper - v2.0 Modular        ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo "📋 Configuration: 1-Edit 2-Show 3-Validate"
        echo "🚀 Setup: 4-Full 5-Monitor"
        echo "⚙️  Service: 6-Enable 7-Disable 8-Start 9-Stop 10-Restart 11-Status 12-Logs"
        echo "💾 Backup: 13-Create 14-Restore 15-List"
        echo "💿 NAS: 16-List 17-Mount"
        echo "🖥️  System: 18-Hostname 19-Clean 20-DiskSpace"
        echo "🔄 Updates: 21-Update 22-FullUpgrade 23-Check 24-Status 25-Reboot"
        echo "🔒 Security: 26-Audit 27-Status 28-Harden 29-fail2ban 30-UFW 31-SSH"
        echo "🗑️  Other: 32-Uninstall"
        echo ""
        echo -e "${GREEN}0) Exit${NC}"
        echo ""
        read -p "Choice [0-32]: " c
        
        case $c in
            1) edit_config; read -p "Press Enter to continue..." ;;
            2) show_config; read -p "Press Enter to continue..." ;;
            3) validate_config; read -p "Press Enter to continue..." ;;
            4) main_setup; read -p "Press Enter to continue..." ;;
            5) 
                warning "Monitor service runs continuously. Press Ctrl+C to stop and return to menu."
                read -p "Press Enter to start monitoring..." 
                monitor_services
                read -p "Press Enter to continue..." 
                ;;
            6) create_systemd_service; read -p "Press Enter to continue..." ;;
            7) remove_systemd_service; read -p "Press Enter to continue..." ;;
            8) start_service_now; read -p "Press Enter to continue..." ;;
            9) stop_service; read -p "Press Enter to continue..." ;;
            10) restart_service; read -p "Press Enter to continue..." ;;
            11) show_service_status; read -p "Press Enter to continue..." ;;
            12) 
                warning "Log viewer runs continuously. Press Ctrl+C to stop and return to menu."
                read -p "Press Enter to view logs..." 
                show_logs
                read -p "Press Enter to continue..." 
                ;;
            13) backup_dockge; read -p "Press Enter to continue..." ;;
            14) restore_dockge; read -p "Press Enter to continue..." ;;
            15) list_backups; read -p "Press Enter to continue..." ;;
            16) list_nas_shares; read -p "Press Enter to continue..." ;;
            17) mount_nas; read -p "Press Enter to continue..." ;;
            18) read -p "New hostname: " h; set_hostname "$h"; read -p "Press Enter to continue..." ;;
            19) clean_disk; read -p "Press Enter to continue..." ;;
            20) show_disk_space; read -p "Press Enter to continue..." ;;
            21) update_system; read -p "Press Enter to continue..." ;;
            22) full_upgrade; read -p "Press Enter to continue..." ;;
            23) check_updates; show_update_status; read -p "Press Enter to continue..." ;;
            24) show_update_status; read -p "Press Enter to continue..." ;;
            25) read -p "Reboot time [${REBOOT_TIME}]: " t; schedule_reboot "${t:-$REBOOT_TIME}"; read -p "Press Enter to continue..." ;;
            26) security_audit; read -p "Press Enter to continue..." ;;
            27) show_security_status; read -p "Press Enter to continue..." ;;
            28) apply_security_hardening; read -p "Press Enter to continue..." ;;
            29) setup_fail2ban; read -p "Press Enter to continue..." ;;
            30) setup_ufw; read -p "Press Enter to continue..." ;;
            31) harden_ssh; read -p "Press Enter to continue..." ;;
            32) 
                uninstall_server_helper
                if [ $? -eq 0 ]; then
                    log "Uninstallation completed. Exiting..."
                    sleep 2
                    exit 0
                else
                    warning "Uninstallation cancelled or incomplete."
                    read -p "Press Enter to continue..."
                fi
                ;;
            0) log "Goodbye!"; exit 0 ;;
            *) error "Invalid choice"; sleep 2 ;;
        esac
    done
}

set_hostname() {
    [ -z "$1" ] && { error "Hostname required"; return 1; }
    validate_hostname "$1" || { error "Invalid hostname"; return 1; }
    
    sudo hostnamectl set-hostname "$1"
    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$1/g" /etc/hosts
    grep -q "127.0.1.1" /etc/hosts || echo "127.0.1.1	$1" | sudo tee -a /etc/hosts
    log "✓ Hostname set to: $1"
}

show_hostname() {
    log "Hostname: $(hostname)"
}

main_setup() {
    log "Running full setup..."
    
    [ -n "$NEW_HOSTNAME" ] && set_hostname "$NEW_HOSTNAME"
    
    mount_nas || [ "$NAS_MOUNT_REQUIRED" = "true" ] && { error "NAS required but failed"; return 1; }
    
    install_docker
    install_dockge
    start_dockge
    
    show_setup_complete
}

show_setup_complete() {
    echo ""
    log "═══════════════════════════════════════"
    log "        Setup Complete!"
    log "═══════════════════════════════════════"
    log "Hostname: $(hostname)"
    log "Dockge: http://localhost:$DOCKGE_PORT"
    list_nas_shares
    echo ""
}
