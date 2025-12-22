#!/bin/bash
# Docker & Dockge Management Module

install_docker() {
    command_exists docker && { log "Docker installed: $(docker --version)"; return 0; }
    
    log "Installing Docker..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
    
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log "✓ Docker installed"
}

install_dockge() {
    log "Setting up Dockge..."
    sudo mkdir -p "$DOCKGE_DATA_DIR/stacks"
    
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
}

start_dockge() {
    log "Starting Dockge..."
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose up -d
    log "✓ Dockge started on port $DOCKGE_PORT"
}

check_dockge_heartbeat() {
    local status=0
    sudo docker ps | grep -q dockge || status=1
    curl -sf http://localhost:$DOCKGE_PORT >/dev/null 2>&1 || status=1
    
    [ -n "$UPTIME_KUMA_DOCKGE_URL" ] && {
        [ $status -eq 0 ] && curl -fsS -m 10 "${UPTIME_KUMA_DOCKGE_URL}?status=up" >/dev/null 2>&1 || \
        curl -fsS -m 10 "${UPTIME_KUMA_DOCKGE_URL}?status=down" >/dev/null 2>&1
    } || true
    
    return $status
}
