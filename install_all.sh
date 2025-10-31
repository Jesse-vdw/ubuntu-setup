#!/usr/bin/env bash
set -euo pipefail

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
