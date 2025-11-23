#!/usr/bin/env bash
set -euo pipefail

# Test if router supports UPnP

echo "🔍 Testing UPnP support..."

# Install miniupnpc if not present
if ! command -v upnpc &> /dev/null; then
    echo "📦 Installing miniupnpc..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y miniupnpc
    elif command -v apk &> /dev/null; then
        sudo apk add miniupnpc
    else
        echo "❌ Cannot install miniupnpc. Please install manually."
        exit 1
    fi
fi

echo ""
echo "Looking for UPnP IGD devices..."
upnpc -l

RESULT=$?

echo ""
if [ $RESULT -eq 0 ]; then
    echo "✅ UPnP is available!"
    echo ""
    echo "To enable automatic port forwarding, uncomment the 'upnpc' service"
    echo "in compose.yaml and restart:"
    echo ""
    echo "  docker compose up -d"
    echo ""
    echo "No manual router configuration needed! 🎉"
else
    echo "❌ UPnP not available or not enabled on router."
    echo ""
    echo "You'll need to manually forward port 51820/udp to this Pi."
    echo ""
    echo "Pi local IP: $(hostname -I | awk '{print $1}')"
fi
