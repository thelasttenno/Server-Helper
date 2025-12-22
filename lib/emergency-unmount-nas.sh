#!/bin/bash
# Emergency NAS Unmount Script
# Run this if the regular uninstaller fails to unmount NAS

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default mount point (change if yours is different)
MOUNT_POINT="${1:-/mnt/nas}"

echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║   Emergency NAS Unmount Script        ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
    echo -e "${RED}✗ Mount point does not exist: $MOUNT_POINT${NC}"
    exit 1
fi

# Check if actually mounted
if ! mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    echo -e "${GREEN}✓ $MOUNT_POINT is not mounted${NC}"
    echo "Cleaning up fstab anyway..."
    sudo sed -i.backup '/cifs.*_netdev/d' /etc/fstab
    echo -e "${GREEN}✓ Done${NC}"
    exit 0
fi

echo "Target: $MOUNT_POINT"
echo ""

# Change to safe directory
echo "Changing to safe directory..."
cd /tmp || cd /

# Show what's using the mount
echo ""
echo -e "${YELLOW}Checking for processes using $MOUNT_POINT...${NC}"
if command -v lsof >/dev/null 2>&1; then
    PROCS=$(sudo lsof "$MOUNT_POINT" 2>/dev/null | tail -n +2)
    if [ -n "$PROCS" ]; then
        echo -e "${YELLOW}Processes found:${NC}"
        echo "$PROCS"
        echo ""
        read -p "Kill these processes? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Killing processes..."
            sudo fuser -km "$MOUNT_POINT" 2>/dev/null || true
            sleep 2
            echo -e "${GREEN}✓ Processes killed${NC}"
        else
            echo -e "${YELLOW}⚠ Warning: Unmount may fail with active processes${NC}"
        fi
    else
        echo -e "${GREEN}✓ No processes found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ lsof not available, skipping process check${NC}"
    echo "Installing lsof is recommended: sudo apt-get install lsof"
fi

# Try unmount methods
echo ""
echo -e "${YELLOW}Attempting to unmount $MOUNT_POINT...${NC}"
echo ""

# Method 1: Normal unmount
echo -n "Method 1: Normal unmount... "
if sudo umount "$MOUNT_POINT" 2>/dev/null; then
    echo -e "${GREEN}✓ Success${NC}"
    SUCCESS=true
else
    echo -e "${RED}✗ Failed${NC}"
    
    # Method 2: Lazy unmount
    echo -n "Method 2: Lazy unmount (-l)... "
    if sudo umount -l "$MOUNT_POINT" 2>/dev/null; then
        echo -e "${GREEN}✓ Success${NC}"
        SUCCESS=true
    else
        echo -e "${RED}✗ Failed${NC}"
        
        # Method 3: Force unmount
        echo -n "Method 3: Force unmount (-f)... "
        if sudo umount -f "$MOUNT_POINT" 2>/dev/null; then
            echo -e "${GREEN}✓ Success${NC}"
            SUCCESS=true
        else
            echo -e "${RED}✗ Failed${NC}"
            
            # Method 4: Force + Lazy
            echo -n "Method 4: Force + Lazy (-fl)... "
            if sudo umount -fl "$MOUNT_POINT" 2>/dev/null; then
                echo -e "${GREEN}✓ Success${NC}"
                SUCCESS=true
            else
                echo -e "${RED}✗ Failed${NC}"
                SUCCESS=false
            fi
        fi
    fi
fi

echo ""

# Check result
if [ "$SUCCESS" = true ]; then
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Unmount Successful!                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    
    # Clean up fstab
    echo ""
    echo "Cleaning up /etc/fstab..."
    sudo cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
    sudo sed -i '/cifs.*_netdev/d' /etc/fstab
    echo -e "${GREEN}✓ Removed CIFS entries from fstab${NC}"
    
    # Remove credential files
    echo ""
    echo "Removing NAS credential files..."
    sudo find /root -name ".nascreds*" -type f -delete 2>/dev/null
    echo -e "${GREEN}✓ Credential files removed${NC}"
    
    echo ""
    echo -e "${GREEN}✓ Complete! NAS fully unmounted and cleaned up.${NC}"
else
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║     All Unmount Methods Failed         ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Remaining processes:${NC}"
    sudo lsof "$MOUNT_POINT" 2>/dev/null || echo "Unable to check (lsof not available)"
    echo ""
    echo -e "${YELLOW}Recommendations:${NC}"
    echo "1. Manually kill remaining processes:"
    echo "   sudo lsof $MOUNT_POINT"
    echo "   sudo kill -9 <PID>"
    echo ""
    echo "2. Stop Docker if running:"
    echo "   cd /opt/dockge && sudo docker compose down"
    echo "   sudo systemctl stop docker"
    echo ""
    echo "3. Stop server-helper service:"
    echo "   sudo systemctl stop server-helper"
    echo ""
    echo "4. Try this script again"
    echo ""
    echo "5. Last resort - reboot:"
    echo "   sudo reboot"
    echo ""
    exit 1
fi
