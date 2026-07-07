#!/usr/bin/env bash

# deploy_vpn_tunnel.sh
# Script til automatisk opsætning af Tailscale (VPN) og Cloudflare Tunnel på Ubuntu.

set -euo pipefail

# Farver til terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}   Tailscale & Cloudflare Tunnel Auto-Deployer      ${NC}"
echo -e "${BLUE}====================================================${NC}"

# Tjek om scriptet køres som root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Fejl: Dette script skal køres som root (brug sudo).${NC}"
    exit 1
fi

# Variabler til tokens
TAILSCALE_KEY=""
CLOUDFLARE_TOKEN=""

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

# Spørg efter tokens hvis de ikke blev givet som argumenter
if [ -z "$TAILSCALE_KEY" ]; then
    echo -e "${YELLOW}Indtast din Tailscale Auth Key (tskey-auth-...):${NC}"
    read -r TAILSCALE_KEY
fi

if [ -z "$CLOUDFLARE_TOKEN" ]; then
    echo -e "${YELLOW}Indtast din Cloudflare Tunnel Token:${NC}"
    read -r CLOUDFLARE_TOKEN
fi

# Tjek om tokens er tomme
if [ -z "$TAILSCALE_KEY" ] || [ -z "$CLOUDFLARE_TOKEN" ]; then
    echo -e "${RED}Fejl: Begge tokens skal angives for at fortsætte.${NC}"
    exit 1
fi

echo -e "\n${BLUE}[1/4] Opdaterer systemet og installerer afhængigheder...${NC}"
apt-get update -y
apt-get install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

echo -e "\n${BLUE}[2/4] Konfigurerer IP Forwarding (kræves for Tailscale exit-node / routing)...${NC}"
# Aktiver IPv4 og IPv6 forwarding midlertidigt og permanent
sysctl -w net.ipv4.ip_forward=1 || true
sysctl -w net.ipv6.conf.all.forwarding=1 || true

cat <<EOF > /etc/sysctl.d/99-vpn-forwarding.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl -p /etc/sysctl.d/99-vpn-forwarding.conf || true

echo -e "\n${BLUE}[3/4] Installerer og konfigurerer Tailscale...${NC}"
# Installer Tailscale via officielt script
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale og forbind med auth key
# Vi konfigurerer den som en exit-node, så den kan fungere som VPN server
echo -e "${YELLOW}Forbinder til Tailscale og aktiverer exit-node...${NC}"
tailscale up --authkey="$TAILSCALE_KEY" --advertise-exit-node --accept-routes

echo -e "\n${BLUE}[4/4] Installerer og konfigurerer Cloudflare Tunnel...${NC}"
# Find systemets arkitektur (amd64, arm64, etc.)
ARCH=$(dpkg --print-architecture)
echo "Detekteret arkitektur: $ARCH"

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo "Downloader cloudflared..."
if [ "$ARCH" = "amd64" ]; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb
elif [ "$ARCH" = "arm64" ]; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
    dpkg -i cloudflared-linux-arm64.deb
else
    # Fallback til generisk binær
    echo -e "${YELLOW}Ukendt eller ikke-understøttet deb-arkitektur ($ARCH). Prøver generisk binær...${NC}"
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH" -O /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
fi

# Ryd op
cd - >/dev/null
rm -rf "$TEMP_DIR"

# Installer Cloudflare Tunnel som en systemd tjeneste med tokenet
echo "Konfigurerer Cloudflare Tunnel service..."
cloudflared service install "$CLOUDFLARE_TOKEN"

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN}   Installation og opsætning er fuldført!           ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "1. ${GREEN}Tailscale${NC} er installeret og tilsluttet."
echo -e "   - Husk at godkende exit-node i dit Tailscale Admin Console:"
echo -e "     https://login.tailscale.com/admin/machines"
echo -e "2. ${GREEN}Cloudflare Tunnel${NC} er installeret og kører som en service."
echo -e "   - Du kan administrere din tunnel direkte i Cloudflare Zero Trust Dashboard:"
echo -e "     https://one.dash.cloudflare.com"
echo -e "===================================================="
