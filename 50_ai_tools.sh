#!/usr/bin/env bash
source "$(dirname "$0")/00_common.sh"
require_root

TARGET_USER=${TARGET_USER:-$(logname 2>/dev/null || echo "jesse")}

log "Using target user '$TARGET_USER' for Docker access"
log "=== AI TOOLS SETUP ==="

curl -fsSL https://ollama.ai/install.sh | sh || warn "Ollama installation skipped."

apt-get update
apt-get install -y docker.io docker-compose-plugin
systemctl enable --now docker

if id "$TARGET_USER" >/dev/null 2>&1; then
  usermod -aG docker "$TARGET_USER"
  log "Added $TARGET_USER to the docker group"
else
  warn "Target user '$TARGET_USER' not found. Skipping docker group membership update."
fi

docker run -d -p 7860:7860 --name langflow ghcr.io/langflow-ai/langflow:latest || true

log "AI tools setup complete ✅"
