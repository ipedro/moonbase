#!/usr/bin/env bash
set -euo pipefail

# Moonbase Setup Script
# Run this on the Raspberry Pi to set up the environment

echo "🌙 Moonbase Setup"
echo "================"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo "❌ Please don't run as root. Run as the pi user."
   exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "✅ Docker installed. Please log out and back in for group changes to take effect."
    exit 0
fi

# Check if in docker group
if ! groups | grep -q docker; then
    echo "⚠️  Adding user to docker group..."
    sudo usermod -aG docker $USER
    echo "✅ Added to docker group. Please log out and back in."
    exit 0
fi

# Check for .env file
if [ ! -f .env ]; then
    echo "⚠️  No .env file found. Copying from .env.example..."
    cp .env.example .env
    echo ""
    echo "📝 Please edit .env with your Cloudflare credentials:"
    echo "   nano .env"
    echo ""
    echo "Then run this script again."
    exit 0
fi

# Get local IP
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "📍 Pi local IP: $LOCAL_IP"
echo ""

# Test UPnP support
echo "🔍 Testing UPnP support..."
if bash scripts/test-upnp.sh &> /dev/null; then
    echo "✅ UPnP detected! Automatic port forwarding will be configured."
    echo ""
    read -p "Enable automatic UPnP port forwarding? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # UPnP service is already uncommented in compose.yaml
        echo "✅ UPnP service will be started"
        UPNP_ENABLED=true
    else
        # Comment out UPnP service
        sed -i '/^  upnpc:/,/^  wireguard:/{ /^  upnpc:/,/^    restart: unless-stopped$/s/^/#/; /^  wireguard:/!b; s/^#//; }' compose.yaml
        UPNP_ENABLED=false
    fi
else
    echo "⚠️  UPnP not detected. You'll need manual port forwarding."
    # Comment out UPnP service
    sed -i '/^  upnpc:/,/^  wireguard:/{ /^  upnpc:/,/^    restart: unless-stopped$/s/^/#/; /^  wireguard:/!b; s/^#//; }' compose.yaml
    UPNP_ENABLED=false
fi
echo ""

# Start services
echo "🚀 Starting services..."
docker compose up -d

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
if [ "${UPNP_ENABLED:-false}" = true ]; then
    echo "✅ UPnP enabled - port forwarding is automatic!"
else
    echo "1. Configure port forwarding on router: 51820/udp → $LOCAL_IP"
fi
echo "2. Wait ~1 minute for WireGuard to generate configs"
echo "3. Get client config: docker exec wireguard /app/show-peer 1"
echo ""
echo "View logs: docker compose logs -f"
