# Tailscale & Cloudflare Tunnel Docker Deployer

Dette repository indeholder en komplet, færdig løsning til lynhurtigt at deploye både **Tailscale VPN (som exit-node)** og **Cloudflare Tunnel** på en Ubuntu-server eller en Proxmox LXC-container ved brug af **Docker Compose**.

## Hvad gør denne løsning?
- **Dockerized**: Både Tailscale og Cloudflare Tunnel kører i isolerede Docker-containere. Det gør det ekstremt nemt at opdatere, fjerne og administrere dem uden at rode dit underliggende system til.
- **Automatisk installation**: Vores `deploy.sh` script installerer automatisk Docker og Docker Compose på din maskine, hvis det ikke allerede er installeret.
- **Sikkerhed i fokus**: Dine private tokens gemmes i en lokal `.env` fil, som automatisk er tilføjet til `.gitignore`, så du aldrig risikerer at uploade dem til GitHub ved en fejl.
- **IP Forwarding**: Scriptet aktiverer automatisk IPv4 og IPv6 forwarding på serveren, så din Tailscale container kan bruges som en fuld VPN-gateway (exit-node).

---

## Hurtig Start (Ubuntu / Proxmox LXC)

For at køre opsætningen på din server skal du blot hente dette repository og køre deploy-scriptet:

```bash
# Gør deploy scriptet eksekverbart
chmod +x deploy.sh

# Kør scriptet (det vil spørge efter dine to tokens interaktivt)
sudo ./deploy.sh

# ELLER kør direkte med tokens som parametre
sudo ./deploy.sh --tailscale "tskey-auth-..." --cloudflare "din-cloudflare-token"
```

*Bemærk: Hvis du vil fjerne eller stoppe containerne senere, kan du blot køre `docker compose down` i denne mappe.*

---

## Opsætning i Proxmox VE (LXC-container)

Det anbefales kraftigt at køre denne løsning i en letvægts **LXC-container** (Ubuntu) i Proxmox frem for en fuld virtuel maskine.

### 1. Opret LXC Containeren
Opret en standard Ubuntu LXC container i Proxmox.

### 2. Aktiver TUN og Nesting (VIGTIGT)
For at Docker kan køre, og for at Tailscale kan oprette sin VPN-tunnel inde i en LXC-container, skal du aktivere **Nesting** og **TUN**.

**Via Proxmox UI:**
1. Vælg din LXC container i venstre menu.
2. Gå til **Options** -> **Features** i midten.
3. Klik **Edit** og kryds af i både **Nesting** og **TUN**.
4. Klik **OK** og start (eller genstart) containeren.

*Alt kører nu fuldstændig smertefrit via Docker inde i din container!*

---

## Efter installationen

### 1. Godkend din Tailscale Exit-Node
Da Tailscale-containeren er konfigureret til at fungere som en "exit-node" (så du kan rute al din internettrafik igennem din server), skal du godkende denne adfærd i dit Tailscale kontrolpanel:
1. Log ind på din [Tailscale Admin Console](https://login.tailscale.com/admin/machines).
2. Find din nye maskine (navngivet `ubuntu-vpn-server` eller dit containers hostname).
3. Klik på de tre prikker (`...`) ved siden af maskinen og vælg **Edit route settings**.
4. Slå **Use as exit node** til.
5. Du kan nu vælge denne server som din "Exit Node" i din Tailscale-app på din mobil eller computer for at rute al din internettrafik igennem den.

### 2. Konfigurer din Cloudflare Tunnel
Din Cloudflare Tunnel container vil automatisk forbinde til Cloudflare. Du kan administrere, hvilke interne tjenester, domæner eller IP-adresser den skal pege på direkte i dit [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com) under **Access** -> **Tunnels**.

---

## GitHub Setup (Push til dit eget repository)

For at uploade dette til din egen private eller offentlige GitHub-konto:

1. Opret et nyt repository på [GitHub](https://github.com/new).
2. Kør følgende kommandoer i denne mappe:

```bash
# Initialiser Git og tilføj filerne
git init
git add .
git commit -m "Initial commit: Dockerized Tailscale and Cloudflare Tunnel deployer"

# Sæt gren-navnet til main
git branch -M main

# Forbind til dit GitHub repository (erstat med dit rigtige GitHub URL)
git remote add origin https://github.com/DIT_BRUGERNAVN/DIT_REPO_NAVN.git

# Push filerne
git push -u origin main
```
