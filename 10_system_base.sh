#!/usr/bin/env bash
source "$(dirname "$0")/00_common.sh"
require_root

HOSTNAME="RND-LAPTOP01"
TIMEZONE="Europe/Amsterdam"
LOCALE="en_US.UTF-8"

log "=== SYSTEM SETUP ==="

# Remove unwanted apps
apt-get remove -y thunderbird libreoffice* rhythmbox totem aisleriot transmission-* simple-scan || true

# Autoremove and clean
apt-get autoremove -y && apt-get clean

# Set hostname, timezone, and locale
hostnamectl set-hostname "$HOSTNAME"
timedatectl set-timezone "$TIMEZONE" && timedatectl set-ntp true
update-locale LANG="$LOCALE"

# Install essential system tools
apt-get update
apt-get install -y ubuntu-drivers-common fwupd bleachbit stacer inxi

# Set up weekly unattended upgrades (every Friday at 03:00)
apt-get install -y unattended-upgrades
cat >/etc/systemd/system/unattended-upgrades-weekly.timer <<'EOF'
[Unit]
Description=Weekly unattended upgrades (Friday)
[Timer]
OnCalendar=Fri *-*-* 03:00:00
Persistent=true
[Install]
WantedBy=timers.target
EOF

# Reload systemd to recognize new timer
systemctl daemon-reload
systemctl enable --now unattended-upgrades-weekly.timer

# Final cleanup
apt-get autoremove -y && apt-get clean

log "System setup complete ✅"
