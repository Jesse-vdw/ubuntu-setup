#!/usr/bin/env bash
source "$(dirname "$0")/00_common.sh"
require_root

log "=== AI TOOLS SETUP ==="

curl -fsSL https://ollama.ai/install.sh | sh || warn "Ollama installation skipped."

apt-get update
apt-get install -y docker.io docker-compose-plugin
systemctl enable --now docker
docker run -d -p 7860:7860 --name langflow ghcr.io/langflow-ai/langflow:latest || true

log "AI tools setup complete ✅"
