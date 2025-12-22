#!/bin/bash
# Interactive Menu Module - Enhanced with Config Backup Options and Debug Visibility

show_menu() {
    while true; do
        clear
        echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║    Server Helper - v2.0 Modular        ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
        
        # Show DEBUG status if enabled
        if [ "$DEBUG" = "true" ]; then
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}         [DEBUG MODE ENABLED]            ${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        fi
        
        # Show DRY_RUN status if enabled
        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${YELLOW}   [DRY-RUN MODE - No changes made]     ${NC}"
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        fi
        
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
        
        debug "Menu selection: $c"
        
        case $c in
            1) 
                debug "Executing: edit_config"
                edit_config
                debug "Completed: edit_config"
                read -p "Press Enter..." 
                ;;
            2) 
                debug "Executing: show_config"
                show_config
                debug "Completed: show_config"
                read -p "Press Enter..." 
                ;;
            3) 
                debug "Executing: validate_config"
                validate_config
                debug "Completed: validate_config"
                read -p "Press Enter..." 
                ;;
            4) 
                debug "Executing: main_setup"
                main_setup
                debug "Completed: main_setup"
                ;;
            5) 
                debug "Executing: monitor_services"
                monitor_services
                debug "Completed: monitor_services"
                ;;
            6) 
                debug "Executing: create_systemd_service"
                create_systemd_service
                debug "Completed: create_systemd_service"
                read -p "Press Enter..." 
                ;;
            7) 
                debug "Executing: remove_systemd_service"
                remove_systemd_service
                debug "Completed: remove_systemd_service"
                read -p "Press Enter..." 
                ;;
            8) 
                debug "Executing: start_service_now"
                start_service_now
                debug "Completed: start_service_now"
                read -p "Press Enter..." 
                ;;
            9) 
                debug "Executing: stop_service"
                stop_service
                debug "Completed: stop_service"
                read -p "Press Enter..." 
                ;;
            10) 
                debug "Executing: restart_service"
                restart_service
                debug "Completed: restart_service"
                read -p "Press Enter..." 
                ;;
            11) 
                debug "Executing: show_service_status"
                show_service_status
                debug "Completed: show_service_status"
                read -p "Press Enter..." 
                ;;
            12) 
                debug "Executing: show_logs"
                show_logs
                debug "Completed: show_logs"
                ;;
            13) 
                debug "Executing: backup_dockge"
                backup_dockge
                debug "Completed: backup_dockge"
                read -p "Press Enter..." 
                ;;
            14) 
                debug "Executing: backup_config_files"
                backup_config_files
                debug "Completed: backup_config_files"
                read -p "Press Enter..." 
                ;;
            15) 
                debug "Executing: backup_all"
                backup_all
                debug "Completed: backup_all"
                read -p "Press Enter..." 
                ;;
            16) 
                debug "Executing: restore_dockge"
                restore_dockge
                debug "Completed: restore_dockge"
                read -p "Press Enter..." 
                ;;
            17) 
                debug "Executing: restore_config_files"
                restore_config_files
                debug "Completed: restore_config_files"
                read -p "Press Enter..." 
                ;;
            18) 
                debug "Executing: list_backups"
                list_backups
                debug "Completed: list_backups"
                read -p "Press Enter..." 
                ;;
            19) 
                debug "Executing: list_nas_shares"
                list_nas_shares
                debug "Completed: list_nas_shares"
                read -p "Press Enter..." 
                ;;
            20) 
                debug "Executing: mount_nas"
                mount_nas
                debug "Completed: mount_nas"
                read -p "Press Enter..." 
                ;;
            21) 
                debug "Prompting for hostname"
                read -p "New hostname: " h
                debug "User entered hostname: $h"
                debug "Executing: set_hostname $h"
                set_hostname "$h"
                debug "Completed: set_hostname"
                read -p "Press Enter..." 
                ;;
            22) 
                debug "Executing: clean_disk"
                clean_disk
                debug "Completed: clean_disk"
                read -p "Press Enter..." 
                ;;
            23) 
                debug "Executing: show_disk_space"
                show_disk_space
                debug "Completed: show_disk_space"
                read -p "Press Enter..." 
                ;;
            24) 
                debug "Executing: update_system"
                update_system
                debug "Completed: update_system"
                read -p "Press Enter..." 
                ;;
            25) 
                debug "Executing: full_upgrade"
                full_upgrade
                debug "Completed: full_upgrade"
                ;;
            26) 
                debug "Executing: check_updates and show_update_status"
                check_updates
                show_update_status
                debug "Completed: check_updates and show_update_status"
                read -p "Press Enter..." 
                ;;
            27) 
                debug "Executing: show_update_status"
                show_update_status
                debug "Completed: show_update_status"
                read -p "Press Enter..." 
                ;;
            28) 
                debug "Prompting for reboot time (default: ${REBOOT_TIME})"
                read -p "Reboot time [${REBOOT_TIME}]: " t
                debug "User entered time: ${t:-$REBOOT_TIME}"
                debug "Executing: schedule_reboot ${t:-$REBOOT_TIME}"
                schedule_reboot "${t:-$REBOOT_TIME}"
                debug "Completed: schedule_reboot"
                read -p "Press Enter..." 
                ;;
            29) 
                debug "Executing: security_audit"
                security_audit
                debug "Completed: security_audit"
                read -p "Press Enter..." 
                ;;
            30) 
                debug "Executing: show_security_status"
                show_security_status
                debug "Completed: show_security_status"
                read -p "Press Enter..." 
                ;;
            31) 
                debug "Executing: apply_security_hardening"
                apply_security_hardening
                debug "Completed: apply_security_hardening"
                read -p "Press Enter..." 
                ;;
            32) 
                debug "Executing: setup_fail2ban"
                setup_fail2ban
                debug "Completed: setup_fail2ban"
                read -p "Press Enter..." 
                ;;
            33) 
                debug "Executing: setup_ufw"
                setup_ufw
                debug "Completed: setup_ufw"
                read -p "Press Enter..." 
                ;;
            34) 
                debug "Executing: harden_ssh"
                harden_ssh
                debug "Completed: harden_ssh"
                read -p "Press Enter..." 
                ;;
            35) 
                debug "Executing: uninstall_server_helper"
                uninstall_server_helper
                debug "Completed: uninstall_server_helper"
                exit 0 
                ;;
            0) 
                debug "User selected exit"
                log "Goodbye!"
                exit 0 
                ;;
            *) 
                debug "Invalid choice entered: $c"
                error "Invalid choice"
                sleep 2 
                ;;
        esac
    done
}

set_hostname() {
    debug "set_hostname called with: $1"
    [ -z "$1" ] && { error "Hostname required"; return 1; }
    
    debug "Validating hostname: $1"
    validate_hostname "$1" || { error "Invalid hostname"; return 1; }
    
    debug "Setting hostname to: $1 using hostnamectl"
    sudo hostnamectl set-hostname "$1"
    
    debug "Updating /etc/hosts file"
    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$1/g" /etc/hosts
    grep -q "127.0.1.1" /etc/hosts || echo "127.0.1.1	$1" | sudo tee -a /etc/hosts
    
    log "✓ Hostname set to: $1"
}

show_hostname() {
    debug "show_hostname called"
    local hostname=$(hostname)
    debug "Current hostname: $hostname"
    log "Hostname: $hostname"
}

main_setup() {
    debug "main_setup called"
    log "Running full setup..."
    
    if [ -n "$NEW_HOSTNAME" ]; then
        debug "NEW_HOSTNAME is set: $NEW_HOSTNAME"
        set_hostname "$NEW_HOSTNAME"
    else
        debug "NEW_HOSTNAME is not set, skipping hostname change"
    fi
    
    debug "Attempting to mount NAS"
    mount_nas || [ "$NAS_MOUNT_REQUIRED" = "true" ] && { 
        error "NAS required but failed"
        debug "NAS mount failed and NAS_MOUNT_REQUIRED=$NAS_MOUNT_REQUIRED"
        return 1
    }
    
    debug "Installing Docker"
    install_docker
    
    debug "Installing Dockge"
    install_dockge
    
    debug "Starting Dockge"
    start_dockge
    
    debug "Creating initial config backup"
    # Create initial config backup after setup
    backup_config_files
    
    debug "Setup complete, showing summary"
    show_setup_complete
}

show_setup_complete() {
    debug "show_setup_complete called"
    echo ""
    log "═══════════════════════════════════════"
    log "        Setup Complete!"
    log "═══════════════════════════════════════"
    log "Hostname: $(hostname)"
    log "Dockge: http://localhost:$DOCKGE_PORT"
    list_nas_shares
    echo ""
}
