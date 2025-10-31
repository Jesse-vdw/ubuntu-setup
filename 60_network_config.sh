#!/usr/bin/env bash
source "$(dirname "$0")/00_common.sh"
require_root

log "=== NETWORK SETUP ==="

apt-get update
apt-get install -y network-manager
systemctl enable --now NetworkManager

WIFI_ENV_FILE="${WIFI_ENV_FILE:-/etc/ubuntu-setup/wifi.env}"

load_wifi_env() {
  if [[ -f "${WIFI_ENV_FILE}.gpg" ]]; then
    if command -v gpg >/dev/null 2>&1; then
      log "Loading Wi-Fi credentials from encrypted ${WIFI_ENV_FILE}.gpg"
      local decrypted tmpfile
      if ! decrypted=$(gpg --batch --quiet --decrypt "${WIFI_ENV_FILE}.gpg"); then
        warn "Failed to decrypt ${WIFI_ENV_FILE}.gpg; skipping Wi-Fi configuration"
        return 1
      fi
      tmpfile=$(mktemp)
      printf '%s\n' "$decrypted" >"$tmpfile"
      set -a
      # shellcheck disable=SC1090,SC1091
      source "$tmpfile"
      set +a
      rm -f "$tmpfile"
      return 0
    else
      warn "gpg is not installed; cannot read ${WIFI_ENV_FILE}.gpg"
      return 1
    fi
  elif [[ -f "$WIFI_ENV_FILE" ]]; then
    log "Loading Wi-Fi credentials from $WIFI_ENV_FILE"
    set -a
    # shellcheck disable=SC1090,SC1091
    source "$WIFI_ENV_FILE"
    set +a
    return 0
  fi

  warn "No Wi-Fi credentials file found at $WIFI_ENV_FILE"
  return 1
}

connect_wifi() {
  local name="$1" ssid="$2" pass="$3"
  if [[ -z "$ssid" || -z "$pass" ]]; then
    warn "Skipping $name: SSID or password not provided"
    return
  fi

  if nmcli connection show "$name" &>/dev/null; then
    log "$name already exists, skipping."
  else
    log "Connecting to $ssid..."
    nmcli device wifi connect "$ssid" password "$pass" name "$name" || warn "Connection failed for $ssid"
  fi
}

try_connect_wifi() {
  local name="$1" ssid_var="$2" pass_var="$3"
  local ssid="${!ssid_var}" pass="${!pass_var}"
  connect_wifi "$name" "$ssid" "$pass"
}

load_wifi_env || true

try_connect_wifi "Home WiFi" HOME_WIFI_SSID HOME_WIFI_PASSWORD
try_connect_wifi "Office WiFi" OFFICE_WIFI_SSID OFFICE_WIFI_PASSWORD

log "Wi-Fi networks configured ✅"
