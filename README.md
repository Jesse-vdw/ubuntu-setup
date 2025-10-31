# Ubuntu Setup Scripts

This repository contains a collection of scripts that automate the provisioning of a Ubuntu workstation.

## Highlights
- `00_common.sh`: Shared helpers used by the other setup scripts.
- `10_system_base.sh`: Prepares core system settings and unattended upgrades.
- `30_developer_env.sh`: Installs the core developer toolchain, applies the Qogir dark blue GNOME theme (ensuring build-time dependencies like `sassc` and the GTK2 engines are preinstalled), and now provisions a reusable "Qogir Material" look-and-feel across GNOME Terminal, VS Code, and Brave. It auto-detects the intended desktop user (via `SUDO_USER`, a `TARGET_USER` variable, or a username argument) and applies user-specific settings for that account while elevating only the commands that need administrator privileges.
- `30_developer_env.sh`: Installs the core developer toolchain, applies the Qogir dark blue GNOME theme, and now provisions a reusable "Qogir Material" look-and-feel across GNOME Terminal, VS Code, and Brave. It auto-detects the intended desktop user (via `SUDO_USER`, a `TARGET_USER` variable, or a username argument) and applies user-specific settings for that account while elevating only the commands that need administrator privileges. The VS Code theme definition lives in `themes/QogirMaterial.json` and is packaged locally so it can be re-installed without marketplace access.
- `30_developer_env.sh`: Installs the core developer toolchain, applies the Qogir dark blue GNOME theme, and now provisions a reusable "Qogir Material" look-and-feel across GNOME Terminal, VS Code, and Brave. It auto-detects the intended desktop user (via `SUDO_USER`, a `TARGET_USER` variable, or a username argument) and applies user-specific settings for that account while elevating only the commands that need administrator privileges. When Brave is available the script saves a custom theme manifest that can be loaded manually via **brave://extensions → Load unpacked**.
- `40_devops_stack.sh`: Configures container tooling and supporting services for DevOps workflows.
- `50_ai_tools.sh`: Installs AI-oriented tooling such as Ollama, Docker, and Langflow. Automatically ensures the target user is part of the `docker` group.
- `60_network_config.sh`: Configures NetworkManager and known Wi-Fi networks.
- `install_all.sh`: Runs the complete provisioning flow in order, delegating user-facing steps to the detected target user and logging the start and completion of each stage. Scripts that are missing or empty are skipped with an informative message.

> **Note:** The scripts look for a `TARGET_USER` environment variable and fall back to the console user (or `jesse`). If the detected user does not exist, the docker group update is skipped with a warning.

After completing the full installation (either by running `install_all.sh` or executing the scripts individually), log out and back in—or run `newgrp docker`—so the refreshed docker group membership takes effect.

Run the scripts individually to target specific areas, or combine them in your own automation pipeline. Each script is safe to rerun; commands that would otherwise fail if a tool is already installed fall back gracefully.

## Providing Wi-Fi credentials

The Wi-Fi setup script reads network secrets from environment variables. For unattended runs, place the secrets in `/etc/ubuntu-setup/wifi.env` (owned by `root:root` and permissioned `600`). The file is sourced as a shell snippet, so define variables in `KEY=value` form:

```bash
HOME_WIFI_SSID="MyHomeSSID"
HOME_WIFI_PASSWORD="SuperSecret"
OFFICE_WIFI_SSID="CorpSSID"
OFFICE_WIFI_PASSWORD="AnotherSecret"
```

At runtime, `60_network_config.sh` skips any network whose SSID or password is unset. Optionally, encrypt the secrets with GnuPG by storing them as `/etc/ubuntu-setup/wifi.env.gpg`; the script will decrypt the file (using `gpg --decrypt`) when NetworkManager is configured. You can also export the same variables in the environment before invoking the script to override the file-based values.

## Hardware and driver inspection

Use the `check_system.sh` helper to capture a comprehensive hardware and driver report before or after provisioning. The script requires root privileges so it can query kernel logs and driver utilities.

```bash
chmod +x check_system.sh
sudo ./check_system.sh | tee driver_check_report.txt
```

> **Optional packages:** Install `mesa-utils`, `v4l-utils`, `inxi`, and GPU vendor diagnostics (`nvidia-utils-*`, `radeontop`, `intel-gpu-tools`) to enable all sections of the report.

## Full installation runner

To execute the entire setup in one pass, run the orchestrator script as root:

```bash
sudo ./install_all.sh
```

The runner logs the start and completion of each stage for easier troubleshooting and stops immediately if any stage fails.
