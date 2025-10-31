# Ubuntu Setup Scripts

This repository contains a collection of scripts that automate the provisioning of a Ubuntu workstation.

## Highlights
- `00_common.sh`: Shared helpers used by the other setup scripts.
- `10_system_base.sh`: Prepares core system settings and unattended upgrades.
- `30_developer_env.sh`: Installs the core developer toolchain. It auto-detects the intended desktop user (via `SUDO_USER`, a `TARGET_USER` variable, or a username argument) and applies user-specific settings for that account while elevating only the commands that need administrator privileges.
- `50_ai_tools.sh`: Installs AI-oriented tooling such as Ollama, Docker, and Langflow.
- `60_network_config.sh`: Configures NetworkManager and known Wi-Fi networks.

Run the scripts individually to target specific areas, or combine them in your own automation pipeline. Each script is safe to rerun; commands that would otherwise fail if a tool is already installed fall back gracefully.
