#!/usr/bin/env bash
source "$(dirname "$0")/00_common.sh"
require_root

log "=== NETWORK SETUP ==="

apt install -y network-manager
systemctl enable --now NetworkManager

connect_wifi() {
  local name="$1" ssid="$2" pass="$3"
  if nmcli connection show "$name" &>/dev/null; then
    log "$name already exists, skipping."
  else
    log "Connecting to $ssid..."
    nmcli device wifi connect "$ssid" password "$pass" name "$name" || warn "Connection failed for $ssid"
  fi
}

connect_wifi "Home WiFi" "MyHomeSSID" "MyHomePassword"
connect_wifi "Office WiFi" "OfficeSSID" "OfficePassword"

log "Wi-Fi networks configured ✅"
