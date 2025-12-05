#!/usr/bin/env bash
set -euo pipefail

# Moonbase deployment script
# Simpler than homelab - only one compose.yaml to manage

REPO_DIR="/home/pi/moonbase"
BRANCH="main"

cd "$REPO_DIR"

echo "🌙 [moonbase] Fetching latest changes..."
git fetch origin "$BRANCH"

# Get list of changed files
CHANGED_FILES=$(git diff --name-only HEAD "origin/$BRANCH" || echo "")

if [ -z "$CHANGED_FILES" ]; then
    echo "✅ [moonbase] No changes detected. Skipping deployment."
    exit 0
fi

echo "📝 [moonbase] Changed files:"
echo "$CHANGED_FILES"

# Reset to latest version
echo "🔄 [moonbase] Updating to latest version..."
git reset --hard "origin/$BRANCH"

# Pull latest images
echo "📦 [moonbase] Pulling latest images..."
COMPOSE_FILES="-f compose.yaml -f compose.media.yaml -f compose.tools.yaml"
docker compose $COMPOSE_FILES pull

# Recreate containers
echo "🚀 [moonbase] Restarting services..."
docker compose $COMPOSE_FILES up -d --remove-orphans

# Cleanup
echo "🧹 [moonbase] Cleaning up unused images..."
docker image prune -f

# Restore SSH remote for local git operations
echo "🔧 [moonbase] Restoring SSH remote..."
git remote set-url origin git@github.com:ipedro/moonbase.git

echo ""
echo "✅ [moonbase] Deployment complete!"
docker compose ps
