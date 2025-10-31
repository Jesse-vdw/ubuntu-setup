#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/00_common.sh"
require_root

TARGET_USER=${TARGET_USER:-$(logname 2>/dev/null || echo "jesse")}
export TARGET_USER

log "Starting full workstation setup (target user: $TARGET_USER)"

"$SCRIPT_DIR/10_system_base.sh"

if [[ -s "$SCRIPT_DIR/30_developer_env.sh" ]]; then
  log "Running developer environment setup as $TARGET_USER"
  if command -v sudo >/dev/null 2>&1; then
    sudo --preserve-env=TARGET_USER -u "$TARGET_USER" -H "$SCRIPT_DIR/30_developer_env.sh"
  else
    su - "$TARGET_USER" -c "TARGET_USER=$TARGET_USER \"$SCRIPT_DIR/30_developer_env.sh\""
  fi
fi

if [[ -s "$SCRIPT_DIR/40_devops_stack.sh" ]]; then
  log "Running devops stack setup"
  "$SCRIPT_DIR/40_devops_stack.sh"
fi

"$SCRIPT_DIR/50_ai_tools.sh"

if [[ -s "$SCRIPT_DIR/60_network_config.sh" ]]; then
  log "Running network configuration"
  "$SCRIPT_DIR/60_network_config.sh"
fi

log "All setup scripts complete ✅"
log "Reminder: log out and back in, or run 'newgrp docker', to use Docker without sudo."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00_common.sh
source "${SCRIPT_DIR}/00_common.sh"

require_root

log "Starting full installation run"

run_stage() {
  local stage_path="$1"
  local stage_name
  stage_name="$(basename "${stage_path}")"

  log "Starting stage: ${stage_name}"
  if "${stage_path}"; then
    log "Completed stage: ${stage_name}"
  else
    error "Stage failed: ${stage_name}"
    exit 1
  fi
}

run_stage "${SCRIPT_DIR}/10_system_base.sh"
run_stage "${SCRIPT_DIR}/30_developer_env.sh"
run_stage "${SCRIPT_DIR}/40_devops_stack.sh"
run_stage "${SCRIPT_DIR}/50_ai_tools.sh"
run_stage "${SCRIPT_DIR}/60_network_config.sh"

log "Full installation run completed successfully"
