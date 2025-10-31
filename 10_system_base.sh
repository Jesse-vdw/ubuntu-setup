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
apt-get install -y ubuntu-drivers-common fwupd bleachbit inxi

# Install Stacer if it's not already present
if ! command -v stacer >/dev/null 2>&1; then
    log "Stacer not found. Preparing installation."

    PPA_ADDED=0
    if ! grep -Rq "^deb .*/oguzhaninan/stacer" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
        log "Adding official Stacer PPA"
        add-apt-repository -y ppa:oguzhaninan/stacer
        PPA_ADDED=1
    fi

    if [[ "$PPA_ADDED" -eq 1 ]]; then
        log "Refreshing package lists after adding Stacer PPA"
        apt-get update
    fi

    apt-get install -y stacer
else
    log "Stacer already installed. Skipping."
fi

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
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now unattended-upgrades-weekly.timer

# Final cleanup
apt-get autoremove -y && apt-get clean

log "System setup complete ✅"
