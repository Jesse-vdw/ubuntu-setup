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

run_as_target_user_capture() {
  if [[ $EUID -eq 0 ]]; then
    sudo -u "$TARGET_USER" HOME="$TARGET_HOME" "$@"
  else
    HOME="$TARGET_HOME" "$@"
  fi
}

run_gsettings() {
  run_as_target_user dbus-run-session -- gsettings "$@"
}

run_gsettings_capture() {
  run_as_target_user_capture dbus-run-session -- gsettings "$@"
}

run_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

write_file_if_changed() {
  local path="$1"
  local content="$2"
  local dir
  dir="$(dirname "$path")"
  run_as_target_user mkdir -p "$dir"
  local tmp
  tmp="$(mktemp)"
  printf '%s' "$content" >"$tmp"
  local existed="no"
  if [[ -f "$path" ]]; then
    existed="yes"
  fi
  if [[ "$existed" == "yes" ]] && cmp -s "$tmp" "$path"; then
    rm -f "$tmp"
    echo "unchanged"
    return 0
  fi
  run_root install -m 644 "$tmp" "$path"
  run_root chown "$TARGET_USER":"$TARGET_USER" "$path"
  rm -f "$tmp"
  if [[ "$existed" == "yes" ]]; then
    echo "updated"
  else
    echo "created"
  fi
}

# Install core tools
run_root apt-get update
run_root apt-get install -y \
  git curl wget build-essential software-properties-common \
  vim jq yq httpie htop gnupg lsb-release ca-certificates dbus-x11

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

# Install Brave browser (official repository)
if ! command -v brave-browser >/dev/null 2>&1; then
  log "Adding Brave browser APT repository and installing brave-browser"
  KEY_PATH="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
  run_root curl -fsSLo "$KEY_PATH" https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  printf 'deb [arch=%s signed-by=%s] https://brave-browser-apt-release.s3.brave.com/ stable main\n' \
    "$(dpkg --print-architecture)" "$KEY_PATH" | run_root tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
  run_root apt-get update
  run_root apt-get install -y brave-browser
else
  log "Brave browser already installed; skipping repository setup"
fi

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
run_gsettings set org.gnome.desktop.interface gtk-theme "Qogir-Dark"
run_gsettings set org.gnome.desktop.interface icon-theme "Qogir"

log "Qogir dark blue theme installation complete ✅"

log "=== Apply Developer Theme (Qogir Material) ==="

log "Configuring GNOME Terminal profile 'Qogir Material'..."
PROFILE_NAME="Qogir Material"
PROFILE_SLUG=$(run_as_target_user_capture python3 - "$PROFILE_NAME" <<'PY'
import subprocess
import sys

profile_name = sys.argv[1]
try:
    listing = subprocess.check_output(['dconf', 'list', '/org/gnome/terminal/legacy/profiles:/'], text=True)
except subprocess.CalledProcessError:
    listing = ''
profile = ''
for line in listing.splitlines():
    line = line.strip()
    if not line.endswith('/'):
        continue
    slug = line[:-1]
    try:
        name = subprocess.check_output(['dconf', 'read', f'/org/gnome/terminal/legacy/profiles:/{slug}/visible-name'], text=True).strip()
    except subprocess.CalledProcessError:
        continue
    if name.strip("'") == profile_name:
        profile = slug
        break
if profile:
    print(profile)
PY
)
PROFILE_SLUG="${PROFILE_SLUG//$'\n'/}"

if [[ -z "$PROFILE_SLUG" ]]; then
  PROFILE_SLUG="$(uuidgen)"
  log "Creating new GNOME Terminal profile with UUID $PROFILE_SLUG"
  PROFILE_LIST_RAW=$(run_gsettings_capture get org.gnome.Terminal.ProfilesList list || echo "[]")
  PROFILE_LIST_UPDATED=$(PROFILE_SLUG="$PROFILE_SLUG" PROFILE_LIST_RAW="$PROFILE_LIST_RAW" python3 - <<'PY'
import ast
import os

slug = os.environ['PROFILE_SLUG']
raw = os.environ['PROFILE_LIST_RAW']
try:
    items = ast.literal_eval(raw)
except Exception:
    items = []
if slug not in items:
    items.append(slug)
print('[' + ', '.join(f"'{item}'" for item in items) + ']')
PY
)
  run_gsettings set org.gnome.Terminal.ProfilesList list "$PROFILE_LIST_UPDATED"
else
  log "Found existing GNOME Terminal profile UUID $PROFILE_SLUG"
fi

run_gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_SLUG/" visible-name "$PROFILE_NAME"
run_gsettings set org.gnome.Terminal.ProfilesList default "'$PROFILE_SLUG'"

QOGIR_TERMINAL_PALETTE="['#1a1f2b', '#ff6f61', '#5cc995', '#f0c674', '#5ab0f6', '#c991e1', '#4cc6d3', '#e6edf3', '#233044', '#ff8a80', '#7adba8', '#ffe08a', '#7fc8ff', '#f2b0ff', '#8ce6f2', '#f8fafc']"
run_gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_SLUG/" use-theme-colors false
run_gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_SLUG/" background-color "'#1a1f2b'"
run_gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_SLUG/" foreground-color "'#e6edf3'"
run_gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_SLUG/" bold-color-same-as-fg false
run_gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_SLUG/" bold-color "'#f8fafc'"
run_gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_SLUG/" palette "$QOGIR_TERMINAL_PALETTE"
run_gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_SLUG/" cursor-colors-set true
run_gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_SLUG/" cursor-background-color "'#5ab0f6'"
run_gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_SLUG/" cursor-foreground-color "'#1a1f2b'"
run_gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_SLUG/" highlight-colors-set true
run_gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_SLUG/" highlight-background-color "'#5ab0f6'"
run_gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_SLUG/" highlight-foreground-color "'#1a1f2b'"
log "Applied Qogir Material palette to GNOME Terminal profile $PROFILE_NAME"

log "Ensuring VS Code Qogir Material theme extension is present..."
VS_CODE_EXTENSION_DIR="$TARGET_HOME/.vscode/extensions/local.qogir-material-1.0.0"
VS_CODE_THEME_PATH="$VS_CODE_EXTENSION_DIR/themes/QogirMaterial.json"
VS_CODE_PACKAGE_PATH="$VS_CODE_EXTENSION_DIR/package.json"
VS_CODE_PACKAGE_JSON=$(cat <<'EOF'
{
  "name": "local.qogir-material",
  "displayName": "Qogir Material",
  "version": "1.0.0",
  "publisher": "local",
  "engines": {
    "vscode": "^1.50.0"
  },
  "categories": [
    "Themes"
  ],
  "contributes": {
    "themes": [
      {
        "label": "Qogir Material",
        "uiTheme": "vs-dark",
        "path": "./themes/QogirMaterial.json"
      }
    ]
  }
}
EOF
)
run_as_target_user mkdir -p "$VS_CODE_EXTENSION_DIR/themes"
VS_CODE_THEME_SOURCE="$(dirname "$0")/themes/QogirMaterial.json"
if [[ ! -f "$VS_CODE_THEME_SOURCE" ]]; then
  error "Theme definition not found at $VS_CODE_THEME_SOURCE"
  exit 1
fi
VS_CODE_THEME_JSON="$(cat "$VS_CODE_THEME_SOURCE")"
VS_CODE_PACKAGE_STATUS=$(write_file_if_changed "$VS_CODE_PACKAGE_PATH" "$VS_CODE_PACKAGE_JSON")
case "$VS_CODE_PACKAGE_STATUS" in
  created) log "Created VS Code extension manifest at $VS_CODE_PACKAGE_PATH" ;;
  updated) log "Updated VS Code extension manifest at $VS_CODE_PACKAGE_PATH" ;;
  unchanged) log "VS Code extension manifest already up to date at $VS_CODE_PACKAGE_PATH" ;;
esac
VS_CODE_THEME_STATUS=$(write_file_if_changed "$VS_CODE_THEME_PATH" "$VS_CODE_THEME_JSON")
case "$VS_CODE_THEME_STATUS" in
  created) log "Created VS Code theme file at $VS_CODE_THEME_PATH" ;;
  updated) log "Updated VS Code theme file at $VS_CODE_THEME_PATH" ;;
  unchanged) log "VS Code theme file already up to date at $VS_CODE_THEME_PATH" ;;
esac
if command -v code >/dev/null 2>&1; then
  run_as_target_user code --install-extension "$VS_CODE_EXTENSION_DIR" || true
fi

log "Setting VS Code to use the Qogir Material theme..."
run_as_target_user mkdir -p "$TARGET_HOME/.config/Code/User"
VSCODE_SETTINGS_STATUS=$(run_as_target_user bash -lc "SETTINGS_PATH='$TARGET_HOME/.config/Code/User/settings.json' THEME_VALUE='$PROFILE_NAME' python3 - <<'PY'
import json
import os

settings_path = os.environ['SETTINGS_PATH']
theme_value = os.environ['THEME_VALUE']

try:
    with open(settings_path, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
except FileNotFoundError:
    data = {}
except json.JSONDecodeError:
    data = {}

if data.get('workbench.colorTheme') == theme_value:
    print('UNCHANGED')
else:
    data['workbench.colorTheme'] = theme_value
    os.makedirs(os.path.dirname(settings_path), exist_ok=True)
    with open(settings_path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, indent=2)
        fh.write('\n')
    print('UPDATED')
PY
")
if [[ "$VSCODE_SETTINGS_STATUS" == "UPDATED" ]]; then
  log "VS Code theme preference updated in settings.json"
else
  log "VS Code theme preference already set to $PROFILE_NAME"
fi

if command -v brave-browser >/dev/null 2>&1; then
  log "Preparing Brave browser Qogir Material theme manifest..."
  BRAVE_THEME_PATH="$TARGET_HOME/.config/BraveSoftware/Brave-Browser/CustomThemes/qogir_material_theme/manifest.json"
  BRAVE_THEME_JSON=$(cat <<'EOF'
{
  "manifest_version": 3,
  "version": "1.0.0",
  "name": "Qogir Material",
  "theme": {
    "colors": {
      "frame": [26, 31, 43],
      "toolbar": [35, 48, 68],
      "tab_text": [230, 237, 243],
      "bookmark_text": [230, 237, 243],
      "button_background": [90, 176, 246],
      "ntp_background": [26, 31, 43],
      "ntp_text": [230, 237, 243]
    }
  }
}
EOF
  )
  BRAVE_THEME_STATUS=$(write_file_if_changed "$BRAVE_THEME_PATH" "$BRAVE_THEME_JSON")
  case "$BRAVE_THEME_STATUS" in
    created) log "Created Brave theme manifest at $BRAVE_THEME_PATH" ;;
    updated) log "Updated Brave theme manifest at $BRAVE_THEME_PATH" ;;
    unchanged) log "Brave theme manifest already up to date at $BRAVE_THEME_PATH" ;;
  esac

  log "To finish applying the Brave theme, load the unpacked theme from $BRAVE_THEME_PATH via brave://extensions"
else
  log "Brave browser not detected; skipping custom theme manifest setup"
fi

log "Developer setup complete ✅"
