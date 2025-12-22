#!/bin/bash
# Docker & Dockge Management Module - Enhanced with Debug

install_docker() {
    debug "install_docker called"
    
    if command_exists docker; then
        local docker_version=$(docker --version)
        log "Docker installed: $docker_version"
        debug "Docker already present: $docker_version"
        return 0
    fi
    
    log "Installing Docker..."
    debug "Docker not found, beginning installation"
    
    debug "Removing old Docker packages"
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    debug "Updating package lists"
    sudo apt-get update
    
    debug "Installing prerequisites"
    sudo apt-get install -y ca-certificates curl gnupg
    
    debug "Setting up Docker GPG key directory"
    sudo install -m 0755 -d /etc/apt/keyrings
    
    debug "Downloading Docker GPG key"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    debug "GPG key installed"
    
    debug "Adding Docker repository"
    local arch=$(dpkg --print-architecture)
    local codename=$(lsb_release -cs)
    debug "Architecture: $arch, Codename: $codename"
    
    echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list
    debug "Docker repository added"
    
    debug "Updating package lists with Docker repo"
    sudo apt-get update
    
    debug "Installing Docker packages"
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    debug "Adding current user ($USER) to docker group"
    sudo usermod -aG docker $USER
    
    debug "Enabling Docker service"
    sudo systemctl enable docker
    
    debug "Starting Docker service"
    sudo systemctl start docker
    
    log "✓ Docker installed"
    debug "Docker installation completed successfully"
}

install_dockge() {
    debug "install_dockge called"
    log "Setting up Dockge..."
    
    debug "Creating Dockge directories: $DOCKGE_DATA_DIR"
    sudo mkdir -p "$DOCKGE_DATA_DIR/stacks"
    debug "Directories created: $DOCKGE_DATA_DIR and $DOCKGE_DATA_DIR/stacks"
    
    debug "Creating docker-compose.yml for Dockge"
    debug "Dockge port: $DOCKGE_PORT"
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
    
    debug "docker-compose.yml created at $DOCKGE_DATA_DIR/docker-compose.yml"
    log "✓ Dockge configured"
}

start_dockge() {
    debug "start_dockge called"
    log "Starting Dockge..."
    
    debug "Changing to Dockge directory: $DOCKGE_DATA_DIR"
    cd "$DOCKGE_DATA_DIR"
    
    debug "Executing docker compose up -d"
    sudo docker compose up -d
    
    log "✓ Dockge started on port $DOCKGE_PORT"
    debug "Dockge startup command completed"
    debug "Access URL: http://localhost:$DOCKGE_PORT"
}

check_dockge_heartbeat() {
    debug "check_dockge_heartbeat called"
    local status=0
    
    debug "Checking if Dockge container is running"
    if sudo docker ps | grep -q dockge; then
        debug "Dockge container found in docker ps"
    else
        debug "Dockge container not found in docker ps"
        status=1
    fi
    
    debug "Checking Dockge web interface on port $DOCKGE_PORT"
    if curl -sf http://localhost:$DOCKGE_PORT >/dev/null 2>&1; then
        debug "Dockge web interface is responding"
    else
        debug "Dockge web interface is not responding"
        status=1
    fi
    
    if [ -n "$UPTIME_KUMA_DOCKGE_URL" ]; then
        debug "Sending heartbeat to Uptime Kuma: $UPTIME_KUMA_DOCKGE_URL"
        if [ $status -eq 0 ]; then
            debug "Sending 'up' status"
            curl -fsS -m 10 "${UPTIME_KUMA_DOCKGE_URL}?status=up" >/dev/null 2>&1
        else
            debug "Sending 'down' status"
            curl -fsS -m 10 "${UPTIME_KUMA_DOCKGE_URL}?status=down" >/dev/null 2>&1
        fi
    else
        debug "No UPTIME_KUMA_DOCKGE_URL configured, skipping heartbeat"
    fi
    
    debug "check_dockge_heartbeat returning status: $status"
    return $status
}
