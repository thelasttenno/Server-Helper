#!/bin/bash
# Docker & Dockge Management Module

install_docker() {
    debug "[install_docker] Checking Docker installation"
    if command_exists docker; then
        log "Docker installed: $(docker --version)"
        return 0
    fi
    
    log "Installing Docker..."
    debug "[install_docker] Removing old Docker packages"
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    debug "[install_docker] Updating package lists"
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    
    debug "[install_docker] Adding Docker GPG key"
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    debug "[install_docker] Adding Docker repository"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
    
    debug "[install_docker] Installing Docker packages"
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    debug "[install_docker] Configuring user and services"
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log "✓ Docker installed"
    debug "[install_docker] Docker installation complete"
}

install_dockge() {
    debug "[install_dockge] Setting up Dockge"
    log "Setting up Dockge..."
    
    debug "[install_dockge] Creating directories: $DOCKGE_DATA_DIR/stacks"
    sudo mkdir -p "$DOCKGE_DATA_DIR/stacks"
    
    debug "[install_dockge] Creating docker-compose.yml"
    sudo bash -c "cat > $DOCKGE_DATA_DIR/docker-compose.yml << 'EOFDC'
version: '3.8'
services:
  dockge:
    image: louislam/dockge:1
    restart: unless-stopped
    ports:
      - '$DOCKGE_PORT:5001'
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/app/data
      - ./stacks:/opt/stacks
    environment:
      - DOCKGE_STACKS_DIR=/opt/stacks
EOFDC"
    log "✓ Dockge configured"
    debug "[install_dockge] Dockge configuration complete"
}

start_dockge() {
    debug "[start_dockge] Starting Dockge service"
    log "Starting Dockge..."
    cd "$DOCKGE_DATA_DIR"
    
    debug "[start_dockge] Running docker compose up -d"
    sudo docker compose up -d
    
    log "✓ Dockge started on port $DOCKGE_PORT"
    debug "[start_dockge] Dockge startup complete"
}

check_dockge_heartbeat() {
    debug "[check_dockge_heartbeat] Checking Dockge status"
    local status=0
    
    if ! sudo docker ps | grep -q dockge; then
        debug "[check_dockge_heartbeat] Dockge container not running"
        status=1
    fi
    
    if ! curl -sf http://localhost:$DOCKGE_PORT >/dev/null 2>&1; then
        debug "[check_dockge_heartbeat] Dockge web interface not responding"
        status=1
    fi
    
    [ -n "$UPTIME_KUMA_DOCKGE_URL" ] && {
        if [ $status -eq 0 ]; then
            debug "[check_dockge_heartbeat] Sending up status to Uptime Kuma"
            curl -fsS -m 10 "${UPTIME_KUMA_DOCKGE_URL}?status=up" >/dev/null 2>&1
        else
            debug "[check_dockge_heartbeat] Sending down status to Uptime Kuma"
            curl -fsS -m 10 "${UPTIME_KUMA_DOCKGE_URL}?status=down" >/dev/null 2>&1
        fi
    } || true
    
    debug "[check_dockge_heartbeat] Heartbeat check complete, status: $status"
    return $status
}
