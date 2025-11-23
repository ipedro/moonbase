# Moonbase 🌙

Remote Raspberry Pi 4 satellite deployment for VPN exit node at parents' location.

## Hardware

- **Raspberry Pi 4 (4GB RAM)**
- Location: Parents' home network
- Purpose: VPN exit node for geo-restricted services

## Services

### Core Services

- **[WireGuard](https://www.wireguard.com/)**: VPN server for secure remote access
  - Port: 51820/udp
  - Generates peer configs automatically
  - Routes all traffic through parents' connection
  
- **[Cloudflare DDNS](https://github.com/oznu/docker-cloudflare-ddns)**: Dynamic DNS updater
  - Updates `moonbase.yourdomain.com` with current IP
  - No port forwarding setup needed on their router
  
- **[Watchtower](https://containrrr.dev/watchtower/)**: Automatic container updates
  - Runs daily at 3 AM
  - Keeps all services up-to-date
  
- **[Portainer Agent](https://www.portainer.io/)**: Remote management
  - Port: 9001
  - Connect from homelab Portainer for remote administration
  
- **[Node Exporter](https://github.com/prometheus/node_exporter)**: System metrics
  - Exports metrics for Prometheus scraping from homelab
  - Monitor Pi health remotely

- **[Code Server](https://github.com/coder/code-server)**: Web-based VS Code
  - Port: 8443
  - Full IDE access via browser
  - Edit configs, check logs, debug remotely
  
- **[GitHub Actions Runner](https://github.com/myoung34/docker-github-actions-runner)**: Self-hosted CI/CD
  - Automatic deployments on git push
  - No SSH needed for updates

## Setup

### Prerequisites

- Raspberry Pi 4 with Raspberry Pi OS (64-bit recommended)
- Docker and Docker Compose installed
- Cloudflare account with API token
- Port forwarding on parents' router: **51820/udp → Pi local IP**

### Installation

1. **Clone repository on the Pi:**
   ```bash
   git clone https://github.com/ipedro/moonbase.git /home/pi/moonbase
   cd /home/pi/moonbase
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   nano .env
   ```
   
   Update with your Cloudflare credentials:
   ```
   CLOUDFLARE_API_TOKEN=your_api_token
   CLOUDFLARE_ZONE=yourdomain.com
   CODE_SERVER_PASSWORD=secure_password_here
   GITHUB_PAT=your_github_personal_access_token
   ```

3. **Start services:**
   ```bash
   docker compose up -d
   ```

4. **Get WireGuard client configs:**
   ```bash
   # Configs are generated in wireguard/config/
   # QR codes for mobile devices:
   docker exec wireguard /app/show-peer 1
   docker exec wireguard /app/show-peer 2
   # etc.
   ```

### Router Configuration

**Port forwarding required:**
- External Port: 51820 (UDP)
- Internal Port: 51820 (UDP)
- Internal IP: Pi's local IP (e.g., 192.168.1.100)

**Find Pi's local IP:**
```bash
hostname -I | awk '{print $1}'
```

## WireGuard Client Setup

### Desktop (Linux/macOS/Windows)

1. **Copy config file from Pi:**
   ```bash
   scp pi@moonbase-ip:/home/pi/moonbase/wireguard/config/peer1/peer1.conf ~/wireguard-moonbase.conf
   ```

2. **Import into WireGuard app:**
   - Install WireGuard from official site
   - Import configuration file
   - Connect!

### Mobile (iOS/Android)

1. **Generate QR code on Pi:**
   ```bash
   docker exec wireguard /app/show-peer 1
   ```

2. **Scan with WireGuard app:**
   - Install WireGuard from App Store/Play Store
   - Add tunnel → Scan QR code
   - Connect!

## Usage

### Connect to VPN

Once connected to WireGuard:
- All your traffic routes through parents' internet connection
- Appears as local citizen for geo-restricted services
- Access parents' local network devices (if needed)

### Split Tunneling (Optional)

To route only specific traffic through the VPN, edit your peer config:

```ini
# Instead of:
AllowedIPs = 0.0.0.0/0

# Use specific routes:
AllowedIPs = 192.168.1.0/24  # Parents' local network only
```

## Management

### Automatic Deployments (GitHub Actions)

Once the GitHub runner is set up, pushes to the `main` branch automatically deploy:

```bash
# From your local machine:
git clone https://github.com/ipedro/moonbase.git
cd moonbase
# Make changes...
git commit -am "Update wireguard config"
git push  # 🚀 Automatically deploys to the Pi!
```

**Setup GitHub Actions runner:**

1. **Create GitHub Personal Access Token:**
   - Go to: https://github.com/settings/tokens
   - Generate new token (classic) with `repo` scope
   - Copy the token

2. **Configure secrets:**
   ```bash
   # From your local machine:
   bash scripts/setup-github-secrets.sh
   ```

3. **Verify runner:**
   - Check: https://github.com/ipedro/moonbase/settings/actions/runners
   - Should show "moonbase-pi" as active

### Remote Web IDE (Code Server)

Access VS Code in your browser at `https://moonbase.yourdomain.com:8443`

- Edit all config files
- Check container logs
- Run docker commands
- No SSH needed

**Secure it with reverse proxy** (recommended):
- Add proxy host in Nginx Proxy Manager
- Domain: `code.moonbase.yourdomain.com`
- Forward to: Pi IP:8443
- Enable SSL

### Remote Management via Portainer

1. **Add environment in homelab Portainer:**
   - Settings → Environments → Add environment
   - Agent type: Docker Standalone
   - URL: `moonbase.yourdomain.com:9001`

2. **Manage remotely:**
   - View logs, restart services, update configs
   - No need to SSH into the Pi

### Monitoring (Optional)

Add to your homelab Prometheus config:

```yaml
scrape_configs:
  - job_name: 'moonbase'
    static_configs:
      - targets: ['moonbase.yourdomain.com:9100']
```

Monitor CPU, memory, disk, network from Grafana.

## Maintenance

### Update all services

Watchtower handles this automatically at 3 AM daily.

**Manual update:**
```bash
cd /home/pi/moonbase
docker compose pull
docker compose up -d
```

### View logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f wireguard
docker compose logs -f cloudflare-ddns
```

### Restart services

```bash
# All services
docker compose restart

# Specific service
docker compose restart wireguard
```

## Troubleshooting

### WireGuard not connecting

1. **Check if service is running:**
   ```bash
   docker compose ps
   ```

2. **Verify port forwarding:**
   ```bash
   # From another network:
   nc -zvu moonbase.yourdomain.com 51820
   ```

3. **Check logs:**
   ```bash
   docker compose logs wireguard
   ```

### DDNS not updating

1. **Check Cloudflare DDNS logs:**
   ```bash
   docker compose logs cloudflare-ddns
   ```

2. **Verify API token has DNS edit permissions**

3. **Manually verify DNS:**
   ```bash
   nslookup moonbase.yourdomain.com
   ```

### No internet through VPN

1. **Check IP forwarding is enabled:**
   ```bash
   docker exec wireguard sysctl net.ipv4.ip_forward
   # Should return: net.ipv4.ip_forward = 1
   ```

2. **Verify AllowedIPs in client config:**
   ```bash
   # Should be:
   AllowedIPs = 0.0.0.0/0
   ```

3. **Test DNS resolution:**
   ```bash
   # While connected to VPN:
   nslookup google.com
   ```

## Security Notes

- **WireGuard keys**: Stored in `wireguard/config/` - keep peer configs secure
- **API tokens**: Never commit `.env` file to git (already in .gitignore)
- **Firewall**: Pi only needs port 51820/udp open to internet
- **Updates**: Watchtower keeps containers patched automatically

## Network Architecture

```
Your Device
    ↓
WireGuard Client
    ↓ (encrypted tunnel)
Internet
    ↓
Parents' Router (port forward 51820)
    ↓
Moonbase Pi (WireGuard Server)
    ↓
Parents' ISP
    ↓
Geo-restricted Services (sees parents' IP)
```

## Resources

- **WireGuard Documentation**: https://www.wireguard.com/
- **Cloudflare API Docs**: https://developers.cloudflare.com/api/
- **Portainer Docs**: https://docs.portainer.io/
- **Homelab Repo**: https://github.com/ipedro/homelab
