#!/usr/bin/env bash

# deploy.sh
# Script til at deploye Tailscale og Cloudflare Tunnel via Docker Compose.

set -euo pipefail

# Farver til terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}   Tailscale & Cloudflare Tunnel Docker Deployer    ${NC}"
echo -e "${BLUE}====================================================${NC}"

# Tjek om scriptet køres som root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Fejl: Dette script skal køres som root (brug sudo).${NC}"
    exit 1
fi

# Tjek om Docker er installeret, ellers installer det
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker blev ikke fundet. Installerer Docker og Docker Compose...${NC}"
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
      
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    echo -e "${GREEN}Docker installeret succesfuldt!${NC}"
fi

# Aktiver IP Forwarding på hosten (kræves for Tailscale exit-node)
echo -e "\n${BLUE}Konfigurerer IP Forwarding på hosten...${NC}"
sysctl -w net.ipv4.ip_forward=1 || true
sysctl -w net.ipv6.conf.all.forwarding=1 || true

cat <<EOF > /etc/sysctl.d/99-vpn-forwarding.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl -p /etc/sysctl.d/99-vpn-forwarding.conf || true

# Håndtering af .env fil
TAILSCALE_KEY=""
CLOUDFLARE_TOKEN=""

# Læs fra eksisterende .env hvis den findes
if [ -f .env ]; then
    echo -e "${BLUE}Fandt eksisterende .env fil.${NC}"
    # Indlæs værdier (ignorér kommentarer)
    export $(grep -v '^#' .env | xargs) || true
fi

# Læs argumenter hvis de findes
while [[ $# -gt 0 ]]; do
    case $1 in
        --tailscale)
            TAILSCALE_KEY="$2"
            shift 2
            ;;
        --cloudflare)
            CLOUDFLARE_TOKEN="$2"
            shift 2
            ;;
        *)
            echo "Ukendt parameter: $1"
            echo "Brug: $0 [--tailscale <token>] [--cloudflare <token>]"
            exit 1
            ;;
    esac
done

# Spørg efter tokens hvis de ikke findes i .env eller argumenter
if [ -z "${TAILSCALE_KEY:-}" ] && [ -z "${TAILSCALE_AUTHKEY:-}" ]; then
    echo -e "${YELLOW}Indtast din Tailscale Auth Key (tskey-auth-...):${NC}"
    read -r TAILSCALE_KEY
else
    TAILSCALE_KEY="${TAILSCALE_KEY:-$TAILSCALE_AUTHKEY}"
fi

if [ -z "${CLOUDFLARE_TOKEN:-}" ]; then
    echo -e "${YELLOW}Indtast din Cloudflare Tunnel Token:${NC}"
    read -r CLOUDFLARE_TOKEN
fi

# Skriv til .env fil
cat <<EOF > .env
TAILSCALE_AUTHKEY=$TAILSCALE_KEY
CLOUDFLARE_TOKEN=$CLOUDFLARE_TOKEN
EOF

chmod 600 .env
echo -e "${GREEN}.env fil opdateret og sikret.${NC}"

# Start containerne via Docker Compose
echo -e "\n${BLUE}Starter Tailscale og Cloudflare Tunnel...${NC}"
docker compose pull
docker compose up -d

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN}   Docker Deployment er startet succesfuldt!        ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "1. ${GREEN}Tailscale Container${NC} kører nu."
echo -e "   - Gå til din Tailscale Admin Console for at godkende exit-node:"
echo -e "     https://login.tailscale.com/admin/machines"
echo -e "2. ${GREEN}Cloudflare Tunnel Container${NC} kører nu."
echo -e "   - Du kan administrere din tunnel direkte i Cloudflare Dashboard:"
echo -e "     https://one.dash.cloudflare.com"
echo -e "===================================================="
