#!/usr/bin/env bash
source "$(dirname "$0")/00_common.sh"
require_root

TARGET_USER=${TARGET_USER:-$(logname 2>/dev/null || echo "jesse")}

log "Using target user '$TARGET_USER' for Docker access"
log "=== AI TOOLS SETUP ==="

OLLAMA_INSTALLER_URL="https://ollama.ai/install.sh"
OLLAMA_INSTALLER_TMP="$(mktemp)"

cleanup_installer() {
  rm -f "$OLLAMA_INSTALLER_TMP"
}
trap cleanup_installer EXIT

if ! curl -fsSL -o "$OLLAMA_INSTALLER_TMP" "$OLLAMA_INSTALLER_URL"; then
  error "Failed to download Ollama installer."
  exit 1
fi

if ! bash "$OLLAMA_INSTALLER_TMP"; then
  error "Ollama installer failed. Aborting stage."
  exit 1
fi

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
