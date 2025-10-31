#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/00_common.sh"
require_root

TARGET_USER=${TARGET_USER:-$(logname 2>/dev/null || echo "jesse")}
export TARGET_USER

run_stage() {
  local stage_path="$1"
  local description="${2:-$(basename "$stage_path")}"

  if [[ ! -s "$stage_path" ]]; then
    log "Skipping ${description} (script not found or empty)."
    return 0
  fi

  log "Starting stage: ${description}"
  if "$stage_path"; then
    log "Completed stage: ${description}"
  else
    error "Stage failed: ${description}"
    exit 1
  fi
}

run_stage_as_target_user() {
  local stage_path="$1"
  local description="${2:-$(basename "$stage_path")}" 

  if [[ ! -s "$stage_path" ]]; then
    log "Skipping ${description} (script not found or empty)."
    return 0
  fi

  log "Starting stage: ${description} as ${TARGET_USER}"
  if command -v sudo >/dev/null 2>&1; then
    if sudo --preserve-env=TARGET_USER -u "$TARGET_USER" -H "$stage_path"; then
      log "Completed stage: ${description}"
    else
      error "Stage failed: ${description}"
      exit 1
    fi
  else
    if su - "$TARGET_USER" -c "TARGET_USER=$TARGET_USER \"$stage_path\""; then
      log "Completed stage: ${description}"
    else
      error "Stage failed: ${description}"
      exit 1
    fi
  fi
}

log "Starting full workstation setup (target user: $TARGET_USER)"

run_stage "$SCRIPT_DIR/10_system_base.sh" "System base setup"
run_stage "$SCRIPT_DIR/30_developer_env.sh" "Developer environment setup"
run_stage "$SCRIPT_DIR/40_devops_stack.sh" "DevOps stack setup"
run_stage "$SCRIPT_DIR/50_ai_tools.sh" "AI tooling setup"
run_stage "$SCRIPT_DIR/60_network_config.sh" "Network configuration"

log "All setup scripts complete ✅"
log "Reminder: log out and back in, or run 'newgrp docker', to use Docker without sudo."
