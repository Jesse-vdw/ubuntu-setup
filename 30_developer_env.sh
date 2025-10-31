#!/usr/bin/env bash
source "$(dirname "$0")/00_common.sh"

USER_NAME="Jessen van de Water"
USER_EMAIL="jvw@bct.nl.com"

DEFAULT_TARGET_USER="jesse"

if [[ -n "${1:-}" ]]; then
  TARGET_USER="$1"
elif [[ -n "${TARGET_USER:-}" ]]; then
  TARGET_USER="$TARGET_USER"
elif [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  TARGET_USER="$SUDO_USER"
else
  TARGET_USER="$DEFAULT_TARGET_USER"
fi

if ! id -u "$TARGET_USER" >/dev/null 2>&1; then
  error "Target user '$TARGET_USER' does not exist. Set TARGET_USER or pass a username as an argument."
  exit 1
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6 || true)"
if [[ -z "$TARGET_HOME" ]]; then
  TARGET_HOME="/home/$TARGET_USER"
fi

if [[ ! -d "$TARGET_HOME" ]]; then
  warn "Home directory $TARGET_HOME not found. Commands will run with HOME=$TARGET_HOME regardless."
fi

log "=== DEVELOPER SETUP (target user: $TARGET_USER | home: $TARGET_HOME) ==="

run_as_target_user() {
  log "Running as $TARGET_USER: $*"
  if [[ $EUID -eq 0 ]]; then
    sudo -u "$TARGET_USER" HOME="$TARGET_HOME" "$@"
  else
    HOME="$TARGET_HOME" "$@"
  fi
}

run_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Install core tools
run_root apt-get update
run_root apt-get install -y \
  git curl wget build-essential software-properties-common \
  vim jq yq httpie htop gnupg lsb-release ca-certificates

ensure_tool_installed() {
  local package_name="$1"
  if ! dpkg -s "$package_name" >/dev/null 2>&1; then
    log "Installing missing package: $package_name"
    run_root apt-get install -y "$package_name"
  else
    log "Package already installed: $package_name"
  fi
}

ensure_tool_installed git
ensure_tool_installed gnome-tweaks

# Configure Git (per target user)
run_as_target_user git config --global user.name "$USER_NAME"
run_as_target_user git config --global user.email "$USER_EMAIL"
run_as_target_user git config --global core.editor "code --wait"
run_as_target_user git config --global init.defaultBranch main

# SSH key setup
SSH_KEY="$TARGET_HOME/.ssh/id_ed25519"
if [[ ! -f "$SSH_KEY" ]]; then
  run_as_target_user ssh-keygen -t ed25519 -C "$USER_EMAIL" -f "$SSH_KEY" -N ""
  if [[ $EUID -eq 0 ]]; then
    PUB_KEY="$(sudo -u "$TARGET_USER" HOME="$TARGET_HOME" cat "${SSH_KEY}.pub")"
  else
    PUB_KEY="$(HOME="$TARGET_HOME" cat "${SSH_KEY}.pub")"
  fi
  log "Generated SSH key for $TARGET_USER: $PUB_KEY"
fi

# Install VSCode if not present
if ! command -v code >/dev/null 2>&1; then
  KEY_FILE=$(mktemp)
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o "$KEY_FILE"
  run_root gpg --dearmor --yes --output /usr/share/keyrings/ms_vscode.gpg "$KEY_FILE"
  run_root chmod 644 /usr/share/keyrings/ms_vscode.gpg
  rm -f "$KEY_FILE"
  printf 'deb [arch=%s] https://packages.microsoft.com/repos/code stable main\n' "$(dpkg --print-architecture)" \
    | run_root tee /etc/apt/sources.list.d/vscode.list >/dev/null
  run_root apt-get update
  run_root apt-get install -y code
fi

# Install VSCode extensions
EXTS=(ms-python.python ms-azuretools.vscode-docker esbenp.prettier-vscode eamodio.gitlens yzhang.markdown-all-in-one)
for ext in "${EXTS[@]}"; do
  run_as_target_user code --install-extension "$ext" || true
done

# Install Node.js via nvm
TARGET_NVM_DIR="$TARGET_HOME/.nvm"
if [[ ! -d "$TARGET_NVM_DIR" ]]; then
  run_as_target_user bash -c 'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash'
fi
run_as_target_user bash -lc 'export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts'

# Install Python
run_root apt-get install -y python3 python3-pip

# Install Snap and DBeaver
if ! command -v snap >/dev/null 2>&1; then
  run_root apt-get install -y snapd
fi
run_root snap install dbeaver-ce

log "Preparing GNOME Qogir dark blue theme installation..."

run_as_target_user mkdir -p "$TARGET_HOME/.themes" "$TARGET_HOME/.icons" "$TARGET_HOME/.cache"

QOGIR_THEME_REPO="https://github.com/vinceliuice/Qogir-theme"
QOGIR_THEME_DIR="$TARGET_HOME/.cache/Qogir-theme"

if [[ -d "$QOGIR_THEME_DIR/.git" ]]; then
  log "Updating existing Qogir theme repository at $QOGIR_THEME_DIR"
  run_as_target_user git -C "$QOGIR_THEME_DIR" pull --ff-only
else
  log "Cloning Qogir theme repository to $QOGIR_THEME_DIR"
  run_as_target_user git clone "$QOGIR_THEME_REPO" "$QOGIR_THEME_DIR"
fi

log "Installing Qogir GTK theme (dark blue variant)"
run_as_target_user bash -lc "cd '$QOGIR_THEME_DIR' && ./install.sh --theme dark --color blue -d '$TARGET_HOME/.themes'"

QOGIR_ICON_REPO="https://github.com/vinceliuice/Qogir-icon-theme"
QOGIR_ICON_DIR="$TARGET_HOME/.cache/Qogir-icon-theme"
QOGIR_ICON_TARGET="$TARGET_HOME/.icons/Qogir"

if [[ ! -d "$QOGIR_ICON_TARGET" ]]; then
  if [[ -d "$QOGIR_ICON_DIR/.git" ]]; then
    log "Updating existing Qogir icon theme repository at $QOGIR_ICON_DIR"
    run_as_target_user git -C "$QOGIR_ICON_DIR" pull --ff-only
  else
    log "Cloning Qogir icon theme repository to $QOGIR_ICON_DIR"
    run_as_target_user git clone "$QOGIR_ICON_REPO" "$QOGIR_ICON_DIR"
  fi
  log "Installing Qogir icon theme"
  run_as_target_user bash -lc "cd '$QOGIR_ICON_DIR' && ./install.sh -d '$TARGET_HOME/.icons'"
else
  log "Qogir icon theme already installed at $QOGIR_ICON_TARGET; skipping reinstall"
fi

log "Applying Qogir theme settings for $TARGET_USER"
run_as_target_user gsettings set org.gnome.desktop.interface gtk-theme "Qogir-Dark"
run_as_target_user gsettings set org.gnome.desktop.interface icon-theme "Qogir"

log "Qogir dark blue theme installation complete ✅"

log "Developer setup complete ✅"
