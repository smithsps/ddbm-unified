#!/usr/bin/env bash
set -e

# Load environment variables from .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

SERVER="${DEPLOY_SERVER}"
REPO_PATH="/etc/nixos/ddbm"

if [ -z "$SERVER" ]; then
  echo "Error: DEPLOY_SERVER not set in .env file"
  exit 1
fi

echo "→ Pushing to git..."
git push

echo "→ Pulling on server..."
ssh "$SERVER" "cd $REPO_PATH && sudo git pull"

echo "→ Rebuilding NixOS..."
ssh "$SERVER" "sudo nixos-rebuild switch"

echo "✓ Deployed!"
echo ""
echo "Logs: ssh $SERVER sudo journalctl -u ddbm -f"
