# Moonbase Copilot Instructions

## Project Overview

**Moonbase** is a remote Raspberry Pi 4 satellite deployment serving as a VPN exit node and management hub at the user's parents' home.

**Key Principle**: Docker Compose-based single-host deployment with automatic deployment via GitHub Actions runner.

## Architecture

### Network Flow
```
Client → WireGuard Client ← (encrypted tunnel) → WireGuard Server (Pi:51820/udp)
         ↓ (connected)
Parents' ISP → Geo-restricted services
```

### Media Pipeline (Servarr + Syncthing)
```
[Moonbase] Sonarr/Radarr → Prowlarr → qBittorrent (Download)
                                          ↓
[Moonbase] Syncthing (Send Only) ← /data/media
            ↓ (Encrypted Sync)
[Homelab]  Syncthing (Receive Only) → Jellyfin (Consume)
```

### Core Components (compose.yaml)

| Service | Purpose | Key Config |
|---------|---------|-----------|
| **wireguard** | VPN server | Port 51820/udp, PEERS=5, ALLOWEDIPS=0.0.0.0/0 |
| **tailscale** | Mesh VPN & Exit Node | Zero-config remote access & geo-unblocking |
| **cloudflare-ddns** | Dynamic DNS updater | Updates moonbase.{CLOUDFLARE_ZONE} |
| **watchtower** | Auto image updates | Runs daily at 3 AM |
| **portainer-agent** | Remote management | Port 9001, connects to homelab Portainer |
| **node-exporter** | Prometheus metrics | Host network mode for system monitoring |
| **github-runner** | CI/CD automation | Self-hosted runner named "moonbase-pi" |
| **upnpc** | UPnP port mapping | Optional - auto-disable if not supported |

### Media Stack (compose.media.yaml)

| Service | Purpose | Key Config |
|---------|---------|-----------|
| **gluetun** | VPN Client | Protects download traffic (AirVPN/WireGuard) |
| **qbittorrent** | Download Client | Networked via Gluetun, downloads to `${DATA_ROOT}` |
| **prowlarr** | Indexer Manager | Networked via Gluetun |
| **sonarr/radarr** | Media Management | Ports 8989/7878, moves to `${DATA_ROOT}/media` |
| **syncthing** | Data Sync | Port 8384, syncs `${DATA_ROOT}/media` to Homelab |

### Tools Stack (compose.tools.yaml)

| Service | Purpose | Key Config |
|---------|---------|-----------|
| **code-server** | Browser-based IDE | Port 8443, full docker.sock access |
| **filebrowser** | Web File Manager | Port 8081, manages `${DATA_ROOT}` |
| **n8n** | Workflow Automation | Port 5678, integrates with Servarr/Discord |

## Critical Implementation Details

### Storage Configuration
- **DATA_ROOT**: Defined in `.env`, points to storage location (e.g., `/mnt/external` or `/home/pi/data`)
- **Hardware**: 256GB High Endurance SD Card used for downloads/buffer
- **Volume Mapping**:
  - qBittorrent: `${DATA_ROOT}/torrents:/data/torrents`
  - Sonarr/Radarr: `${DATA_ROOT}:/data` (enables atomic moves)
  - Syncthing: `${DATA_ROOT}/media:/data/media`

### WireGuard Configuration
- **INTERNAL_SUBNET**: 10.13.13.0 (VPN client IPs)
- **PEERS**: Currently set to 5 (generates 5 client configs)
- **Config storage**: `./wireguard/config/` (peer1, peer2, etc. subdirectories)
- **IP forwarding**: Required - configured in compose.yaml sysctls

### Environment Variables (.env)
**Required for operation:**
- `CLOUDFLARE_API_TOKEN`: Zone-level API token (not account-wide)
- `CLOUDFLARE_ZONE`: Root domain (e.g., "example.com")
- `CODE_SERVER_PASSWORD`: Secure password for web IDE
- `GITHUB_PAT`: Personal Access Token with repo scope for self-hosted runner
- `DATA_ROOT`: Path to media storage (default: `/home/pi/data`)

### Port Configuration
- **51820/udp**: WireGuard (must be forwarded on parents' router)
- **8443/tcp**: Code Server web IDE
- **9001/tcp**: Portainer Agent (internal only, no router forward needed)
- **9100/tcp**: Node Exporter (only accessed by homelab Prometheus)
- **8080/tcp**: qBittorrent Web UI
- **8384/tcp**: Syncthing Web UI
- **8989/7878/9696**: Servarr Web UIs

## Deployment Workflow

### Automatic (GitHub Actions)
1. Push to `main` branch
2. Self-hosted runner (moonbase-pi) executes `scripts/deploy.sh`
3. Script: fetch, check diff, pull images, recreate containers
4. Watchtower also auto-updates daily at 3 AM

### Manual Update
```bash
ssh pi@moonbase-ip
cd /home/pi/moonbase
docker compose pull
docker compose up -d --remove-orphans
```

### Initial Setup Flow
1. `bash setup.sh` on Pi (as non-root `pi` user)
2. Checks Docker installation & user group
3. Checks/creates `.env` from `.env.example`
4. Tests UPnP support via `scripts/test-upnp.sh`
5. Conditionally enables/disables upnpc service
6. Starts all services with `docker compose up -d`

## Common Development Tasks

### Adding a New VPN Client
```bash
# WireGuard auto-generates configs for first N PEERS
# To add more clients, update PEERS env var in compose.yaml and restart:
docker compose up -d wireguard

# Generate QR code for mobile:
docker exec wireguard /app/show-peer 6
```

### Checking Logs
```bash
# All services:
docker compose logs -f

# Specific service:
docker compose logs -f wireguard
docker compose logs wireguard | grep -i error
```

### Accessing Remote Web IDE
- URL: `https://moonbase.yourdomain.com:8443` (direct)
- Better: Reverse proxy through Nginx Proxy Manager for cleaner DNS
- Full filesystem access including docker.sock for CLI operations

### Monitoring via Prometheus
Add to homelab `prometheus.yaml`:
```yaml
scrape_configs:
  - job_name: 'moonbase'
    static_configs:
      - targets: ['moonbase.yourdomain.com:9100']
```

### Updating Single Service
```bash
docker compose up -d SERVICE_NAME
# e.g.: docker compose up -d wireguard
```

## File Structure
- `compose.yaml` — All service definitions
- `setup.sh` — Initial Pi setup (Docker, .env, UPnP detection)
- `scripts/deploy.sh` — GitHub Actions deployment entry point
- `scripts/test-upnp.sh` — Router UPnP capability detection
- `scripts/setup-github-secrets.sh` — Local machine setup for GITHUB_PAT
- `.env.example` — Template for sensitive variables
- `wireguard/config/` — Generated by service, contains peer configs

## Important Patterns

### Idempotent Deployment
- `deploy.sh` checks for changes before restarting
- Uses `git diff` to detect what changed
- Only pulls images & restarts if needed
- Cleans up orphaned containers: `--remove-orphans`

### Non-Root User Requirement
- Setup script explicitly rejects root execution
- Docker group management required for pi user
- Avoids permission issues with volume mounts

### Timezone Configuration
- All services set `TZ=America/Sao_Paulo`
- Important for Watchtower scheduling (3 AM local time)
- Update this if deployment location changes

## Security Considerations

### Secrets Management
- All sensitive vars in `.env` (excluded via `.gitignore`)
- Never commit `.env` to git
- GITHUB_PAT stored as GitHub Actions secret, not in .env

### Network Exposure
- Only 51820/udp needs external access
- Code Server at 8443 should be behind reverse proxy with auth
- Portainer Agent (9001) on internal network only
- Node Exporter (9100) accessed only by homelab Prometheus

### Container Privileges
- WireGuard requires `NET_ADMIN` + `SYS_MODULE` capabilities
- Code Server has docker.sock access (for convenience, note security implications)
- Node Exporter runs with `pid: host` for system metrics

## Troubleshooting Priority Order

1. **Service not running**: `docker compose ps` — check RESTARTING or unhealthy status
2. **Connection issues**: `docker compose logs SERVICE` — check for errors
3. **Port forwarding**: Test externally: `nc -zvu moonbase.yourdomain.com 51820`
4. **DNS**: `nslookup moonbase.yourdomain.com` — verify DDNS updated
5. **IP forwarding**: `docker exec wireguard sysctl net.ipv4.ip_forward` — should return 1

## Integration Points

- **Homelab** (github.com/ipedro/homelab): Portainer (9001), Prometheus (9100), optional Nginx reverse proxy
- **GitHub**: Self-hosted runner for automatic deployment on push
- **Cloudflare**: API token for DDNS (zone-level access required)
- **Parents' Router**: UPnP or manual port forward for 51820/udp

See the [homelab repository](https://github.com/ipedro/homelab) for integration setup and cross-deployment patterns.
