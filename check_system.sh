#!/usr/bin/env bash

set -u
set -o pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "This script must be run as root. Use: sudo $0" >&2
  exit 1
fi

section() {
  local title="$1"
  printf '\n========== %s ==========' "$title"
  printf '\n'
}

run_cmd() {
  local title="$1"
  shift
  local cmd=("$@")

  section "$title"
  if command -v "${cmd[0]}" >/dev/null 2>&1; then
    "${cmd[@]}"
  else
    echo "Skipping: ${cmd[0]} is not available."
  fi
}

run_cmd_with_requirement() {
  local title="$1"
  local requirement="$2"
  shift 2
  local cmd=("$@")

  section "$title"
  if ! command -v "$requirement" >/dev/null 2>&1; then
    echo "Skipping: $requirement is not available."
    return
  fi

  if command -v "${cmd[0]}" >/dev/null 2>&1; then
    "${cmd[@]}"
  else
    echo "Skipping: ${cmd[0]} is not available."
  fi
}

run_custom_cmd() {
  local title="$1"
  shift
  section "$title"
  eval "$*" || true
}

section "Timestamp"
date -Is

run_cmd "Distribution information" lsb_release -a
run_cmd "Kernel and architecture" uname -a
run_cmd "Host firmware" hostnamectl

run_cmd "CPU details" lscpu
run_cmd "Memory information" free -h
run_cmd "NUMA / memory blocks" lsmem
run_cmd "Block devices" lsblk -f
run_cmd "PCI devices" lspci -nnk
run_cmd "USB devices" lsusb
run_cmd "Detailed hardware inventory" lshw -short
run_cmd "Loaded kernel modules" lsmod
run_cmd "DKMS module status" dkms status
run_cmd "Installed drivers (ubuntu-drivers)" ubuntu-drivers devices
run_cmd "Firmware devices (fwupdmgr)" fwupdmgr get-devices
run_cmd "Firmware updates (fwupdmgr)" fwupdmgr get-updates
run_cmd "Graphics diagnostics (glxinfo)" glxinfo -B
run_cmd "GPU status (nvidia-smi)" nvidia-smi
# Capture optional GPU telemetry when vendor tools are present.
run_cmd "AMD GPU telemetry (radeontop)" radeontop -d - -l 1
run_cmd_with_requirement "Intel GPU telemetry (intel_gpu_top)" intel_gpu_top timeout 5 intel_gpu_top -J -s 1000 -o -
run_cmd "V4L2 devices" v4l2-ctl --list-devices
run_cmd "Inxi full report" inxi -Fazy

run_custom_cmd "Recent kernel errors" "journalctl --no-pager -k -p err -n 200"
run_custom_cmd "dmesg tail" "dmesg | tail -n 200"

section "Summary"
echo "Hardware and driver inspection completed. Review the sections above for potential issues."
