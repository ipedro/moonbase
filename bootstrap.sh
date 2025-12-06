#!/bin/bash
set -e

REPO_NAME="moonbase"
REPO_URL="https://github.com/ipedro/${REPO_NAME}.git"
TARGET_DIR="$HOME/Developer/${REPO_NAME}"

echo "🚀 Bootstrapping ${REPO_NAME}..."

# Ensure git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Git is required. Please install it first."
    exit 1
fi

# Clone or Update
if [ -d "$TARGET_DIR" ]; then
    echo "📂 Updating existing repository..."
    cd "$TARGET_DIR"
    git pull
else
    echo "📂 Cloning repository..."
    mkdir -p "$(dirname "$TARGET_DIR")"
    git clone "$REPO_URL" "$TARGET_DIR"
    cd "$TARGET_DIR"
fi

# Run Setup
echo "⚡ Running setup..."
chmod +x setup.sh
./setup.sh
