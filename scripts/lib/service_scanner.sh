#!/usr/bin/env bash
# Server-Helper Service Auto-Discovery Scanner
# Scans existing Docker Compose projects and host-level services
# to prompt for active Traefik and Watchtower management injection.

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "$DIR/utils.sh"

scan_docker_stacks() {
	echo -e "\n${BOLD}${CYAN}[*] Scanning for existing unmanaged Docker Stacks...${NC}"
	local stacks_dir="/opt/stacks"

	if [[ ! -d "$stacks_dir" ]]; then
		echo -e "  » ${DIM}No /opt/stacks directory found. Skipping...${NC}"
		return
	fi

	local found_unmanaged=false
	for compose_file in "$stacks_dir"/*/docker-compose.yml "$stacks_dir"/*/docker-compose.yaml; do
		if [[ -f "$compose_file" ]]; then
			local project_name
			project_name=$(basename "$(dirname "$compose_file")")

			# Check if already managed (has both labels)
			local has_traefik
			local has_watchtower
			has_traefik=$(grep -c "traefik.enable=true" "$compose_file" || true)
			has_watchtower=$(grep -c "watchtower.enable=true" "$compose_file" || true)

			if [[ "$has_traefik" -eq 0 || "$has_watchtower" -eq 0 ]]; then
				found_unmanaged=true
				echo -e "\n${YELLOW}⚠ Found unmanaged stack: ${BOLD}${project_name}${NC}"

				if confirm "Would you like to auto-inject Traefik/Watchtower labels into ${project_name} now?"; then
					# Check domains
					local app_domain=""
					read -rp "  Enter sub-domain for Traefik routing (e.g., 'myapp'): " app_domain
					if [[ -z "$app_domain" ]]; then
						app_domain="$project_name"
					fi

					local target_port=""
					read -rp "  Enter internal application port (e.g., '8080'): " target_port

					if [[ -n "$target_port" ]]; then
						echo -e "  ${DIM}Injecting labels into $compose_file...${NC}"

						# Strip existing basic labels block safely
						sed -i '/labels:/d' "$compose_file"
						sed -i '/traefik./d' "$compose_file"
						sed -i '/watchtower.enable/d' "$compose_file"
						
						# Inject standard proxy labels
						awk -v port="$target_port" -v domain="$app_domain" '
						/services:/ {
							print
							getline
							print
							print "    labels:"
							print "      - \"traefik.enable=true\""
							print "      - \"traefik.http.routers." domain ".rule=Host(`" domain ".{{ target_domain }}`)\""
							print "      - \"traefik.http.routers." domain ".entrypoints=websecure\""
							print "      - \"traefik.http.routers." domain ".tls.certresolver=letsencrypt\""
							print "      - \"traefik.http.services." domain ".loadbalancer.server.port=" port "\""
							print "      - \"com.centurylinklabs.watchtower.enable=true\""
							next
						}
						{print}' "$compose_file" > "$compose_file.tmp" && mv "$compose_file.tmp" "$compose_file"
						
						echo -e "  ${GREEN}✓ Injected Traefik routing rules and Watchtower updates for $project_name${NC}"
					else
						echo -e "  ${RED}✗ Skipped. Port required for Traefik routing.${NC}"
					fi
				fi
			fi
		fi
	done

	if [ "$found_unmanaged" = false ]; then
		echo -e "  ${GREEN}✓ All existing Docker stacks are fully managed.${NC}"
	fi
}

scan_host_services() {
	echo -e "\n${BOLD}${CYAN}[*] Scanning for unmanaged host (non-Docker) services...${NC}"
	
	if ! command -v ss &>/dev/null; then
		echo -e "  ${DIM}ss command not found, skipping host scan...${NC}"
		return
	fi

	# Find listener ports except SSH (22), Docker Proxy (2375), and Traefik standard ports
	local listening_ports
	listening_ports=$(ss -tlpn | awk 'NR>1 {print $4}' | grep -v '127.0.0.1' | grep -vE ':(22|80|443|8080|2375|53)$' || true)

	if [[ -z "$listening_ports" ]]; then
		echo -e "  ${GREEN}✓ No unknown bare-metal services detected.${NC}"
		return
	fi

	local unhandled_services_found=false
	for addr in $listening_ports; do
		# Extract IP and Port
		local host_ip
		local host_port
		host_ip=$(echo "$addr" | rev | cut -d: -f2- | rev)
		host_port=$(echo "$addr" | awk -F: '{print $NF}')

		if [[ "$host_ip" == "*" || "$host_ip" == "0.0.0.0" || "$host_ip" == "[::]" ]]; then
			host_ip="127.0.0.1" # Route through local loopback from Traefik
		fi

		unhandled_services_found=true
		echo -e "\n${YELLOW}⚠ Discovered active service on port: ${BOLD}${host_port}${NC}"
		
		if confirm "Would you like to map port ${host_port} into Traefik dynamically?"; then
			local app_name=""
			read -rp "  Enter an identifier for this service (e.g., 'myapp'): " app_name
			if [[ -n "$app_name" ]]; then
				local dynamic_config="/opt/Server-Helper/roles/traefik/templates/dynamic-config.yml.j2"
				if [[ -f "$dynamic_config" ]]; then
					echo -e "\n  # Auto-injected by Service Scanner" >> "$dynamic_config"
					echo "  routers:" >> "$dynamic_config"
					echo "    ${app_name}-ext:" >> "$dynamic_config"
					echo "      rule: Host(\`${app_name}.{{ target_domain }}\`)" >> "$dynamic_config"
					echo "      entryPoints:" >> "$dynamic_config"
					echo "        - websecure" >> "$dynamic_config"
					echo "      service: ${app_name}-ext-svc" >> "$dynamic_config"
					echo "      tls:" >> "$dynamic_config"
					echo "        certResolver: letsencrypt" >> "$dynamic_config"
					echo "  services:" >> "$dynamic_config"
					echo "    ${app_name}-ext-svc:" >> "$dynamic_config"
					echo "      loadBalancer:" >> "$dynamic_config"
					echo "        servers:" >> "$dynamic_config"
					echo "          - url: \"http://${host_ip}:${host_port}\"" >> "$dynamic_config"
					echo -e "  ${GREEN}✓ Injected Traefik dynamic file-provider rules for port ${host_port}${NC}"
				else
					echo -e "  ${RED}✗ Could not find dynamic-config.yml.j2 template.${NC}"
				fi
			fi
		fi
	done

	if [ "$unhandled_services_found" = false ]; then
		echo -e "  ${GREEN}✓ No unmanaged bare-metal services found.${NC}"
	fi
}

# Execute scanner
scan_docker_stacks
scan_host_services
