#!/usr/bin/env bash
source "$(dirname "$0")/00_common.sh"

USER_NAME="Jessen van de Water"
USER_EMAIL="jvw@bct.nl.com"

log "=== DEVELOPER SETUP ==="

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

# Configure Git
git config --global user.name "$USER_NAME"
git config --global user.email "$USER_EMAIL"
git config --global core.editor "code --wait"
git config --global init.defaultBranch main

# SSH key setup
SSH_KEY="$HOME/.ssh/id_ed25519"
if [[ ! -f "$SSH_KEY" ]]; then
  ssh-keygen -t ed25519 -C "$USER_EMAIL" -f "$SSH_KEY" -N ""
  log "Generated SSH key: $(cat "${SSH_KEY}.pub")"
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
  code --install-extension "$ext" || true
done

# Install Node.js via nvm
if [[ ! -d "$HOME/.nvm" ]]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
fi
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts

# Install Python
run_root apt-get install -y python3 python3-pip

# Install Snap and DBeaver
if ! command -v snap >/dev/null 2>&1; then
  run_root apt-get install -y snapd
fi
run_root snap install dbeaver-ce

log "Developer setup complete ✅"
