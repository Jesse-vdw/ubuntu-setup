# Ubuntu Setup Scripts

This repository contains a collection of scripts that automate the provisioning of a Ubuntu workstation.

## Highlights
- `00_common.sh`: Shared helpers used by the other setup scripts.
- `10_system_base.sh`: Prepares core system settings and unattended upgrades.
- `30_developer_env.sh`: Installs the core developer toolchain. This script now elevates only the commands that require administrator privileges, so it can be invoked either as a regular user (with sudo available) or as root.
- `50_ai_tools.sh`: Installs AI-oriented tooling such as Ollama, Docker, and Langflow.
- `60_network_config.sh`: Configures NetworkManager and known Wi-Fi networks.

Run the scripts individually to target specific areas, or combine them in your own automation pipeline. Each script is safe to rerun; commands that would otherwise fail if a tool is already installed fall back gracefully.
