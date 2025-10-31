# Ubuntu Setup Scripts

This repository contains a collection of scripts that automate the provisioning of a Ubuntu workstation.

## Highlights
- `00_common.sh`: Shared helpers used by the other setup scripts.
- `10_system_base.sh`: Prepares core system settings and unattended upgrades.
- `30_developer_env.sh`: Installs the core developer toolchain. This script now elevates only the commands that require administrator privileges, so it can be invoked either as a regular user (with sudo available) or as root.
- `50_ai_tools.sh`: Installs AI-oriented tooling such as Ollama, Docker, and Langflow. Automatically ensures the target user is part of the `docker` group.
- `40_devops_stack.sh`: Configures container tooling and supporting services for DevOps workflows.
- `50_ai_tools.sh`: Installs AI-oriented tooling such as Ollama, Docker, and Langflow.
- `60_network_config.sh`: Configures NetworkManager and known Wi-Fi networks.
- `install_all.sh`: Runs the complete provisioning flow in order, delegating user-facing steps to the detected target user.

> **Note:** The scripts look for a `TARGET_USER` environment variable and fall back to the console user (or `jesse`). If the detected user does not exist, the docker group update is skipped with a warning.

After completing the full installation (either by running `install_all.sh` or executing the scripts individually), log out and back in—or run `newgrp docker`—so the refreshed docker group membership takes effect.

Run the scripts individually to target specific areas, or combine them in your own automation pipeline. Each script is safe to rerun; commands that would otherwise fail if a tool is already installed fall back gracefully.

## Full installation runner

To execute the entire setup in one pass, run the orchestrator script as root:

```bash
sudo ./install_all.sh
```

The runner logs the start and completion of each stage for easier troubleshooting and stops immediately if any stage fails.
