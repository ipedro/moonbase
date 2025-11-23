#!/usr/bin/env bash
set -euo pipefail

# Setup GitHub Actions self-hosted runner secrets
# Run this from your local machine (not on the Pi)

echo "🔐 Setting up GitHub secrets for Moonbase"
echo "========================================="
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found. Install it first:"
    echo "   https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub. Run: gh auth login"
    exit 1
fi

echo "📝 This will set up secrets for GitHub Actions self-hosted runner."
echo ""
echo "You'll need:"
echo "  1. GitHub Personal Access Token (repo scope)"
echo "  2. Moonbase Pi SSH access (for runner setup)"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Set GITHUB_TOKEN secret (for deployment workflow)
echo ""
echo "The GITHUB_TOKEN will be automatically provided by GitHub Actions."
echo "No manual setup needed for that."

# Set GITHUB_PAT for runner
echo ""
read -p "Enter your GitHub Personal Access Token (repo scope): " GITHUB_PAT
gh secret set GITHUB_PAT --repo ipedro/moonbase --body "$GITHUB_PAT"
echo "✅ Set GITHUB_PAT secret"

echo ""
echo "✅ Secrets configured!"
echo ""
echo "Next steps:"
echo "1. On the Moonbase Pi, create .env file:"
echo "   cp .env.example .env"
echo "   nano .env  # Add your GITHUB_PAT and other credentials"
echo ""
echo "2. Start the GitHub runner:"
echo "   docker compose up -d github-runner"
echo ""
echo "3. Verify runner is registered:"
echo "   https://github.com/ipedro/moonbase/settings/actions/runners"
