#!/bin/bash
# Run on Supabase VM to install Docker and start Supabase self-hosted.
# Usage: bash setup-supabase-vm.sh
# Pre-requisite: Set environment variables before running:
#   export JWT_SECRET=...
#   export ANON_KEY=...
#   export SERVICE_ROLE_KEY=...
#   export SITE_URL=http://<this-vm-external-ip>:8000
#   export POSTGRES_PASSWORD=...
set -euo pipefail

# Validate required env vars
: "${JWT_SECRET:?JWT_SECRET must be set}"
: "${ANON_KEY:?ANON_KEY must be set}"
: "${SERVICE_ROLE_KEY:?SERVICE_ROLE_KEY must be set}"
: "${SITE_URL:?SITE_URL must be set (e.g. http://1.2.3.4:8000)}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD must be set}"

# Install Docker
echo "==> Installing Docker..."
sudo apt-get update -qq
sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -qq
sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker "$USER"
echo "==> Docker installed: $(sudo docker --version)"

# Clone Supabase self-hosted config
echo "==> Downloading Supabase Docker Compose..."
SUPABASE_DIR="$HOME/supabase"
if [ -d "$SUPABASE_DIR" ]; then
  echo "  Already exists, pulling latest..."
  git -C "$SUPABASE_DIR" pull
else
  git clone --filter=blob:none --sparse https://github.com/supabase/supabase "$SUPABASE_DIR"
  git -C "$SUPABASE_DIR" sparse-checkout set docker
fi

cd "$SUPABASE_DIR/docker"

# Configure .env
echo "==> Writing .env..."
cp .env.example .env

# Replace values in .env
sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" .env
sed -i "s|^JWT_SECRET=.*|JWT_SECRET=${JWT_SECRET}|" .env
sed -i "s|^ANON_KEY=.*|ANON_KEY=${ANON_KEY}|" .env
sed -i "s|^SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}|" .env
sed -i "s|^SITE_URL=.*|SITE_URL=${SITE_URL}|" .env
sed -i "s|^API_EXTERNAL_URL=.*|API_EXTERNAL_URL=${SITE_URL}|" .env

# Start all services
echo "==> Starting Supabase (this takes 2-3 minutes on first run)..."
sudo docker compose up -d

echo ""
echo "==> Supabase started!"
echo ""
echo "Service URLs:"
echo "  Kong API:   ${SITE_URL}"
echo "  Studio:     http://localhost:3000  (access via SSH tunnel)"
echo ""
echo "Credentials to store in Secret Manager:"
echo "  SUPABASE_URL=${SITE_URL}"
echo "  SUPABASE_ANON_KEY=${ANON_KEY}"
echo "  SUPABASE_SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}"
echo "  SUPABASE_JWT_SECRET=${JWT_SECRET}"
echo ""
echo "DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@localhost:5432/postgres"
