#!/usr/bin/env bash
set -euo pipefail
# IFS=$'\n\t'  # Only set if doing loops or processing multiline input

GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

log()   { printf "${GREEN}[%s]${RESET} %s\n" "$(date +'%H:%M:%S')" "$*"; }
warn()  { printf "${YELLOW}[WARN]${RESET} %s\n" "$*"; }
error() { printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    error "Please run as root (sudo)."
    exit 1
  fi
}
