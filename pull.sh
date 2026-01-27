#!/usr/bin/env bash
set -euo pipefail

# Download opencode.jsonc + oh-my-opencode.jsonc from your Gist and overwrite *user-level* config.
# After install, if opencode.json / oh-my-opencode.json exists, rename it to *.json.bak-<timestamp>
# so only *.jsonc remains as the active config.

GIST_USER="${GIST_USER:-ControlNet}"
GIST_ID="${GIST_ID:-b10f23a707e3515e8fd215770e929b1a}"
GIST_REV="${GIST_REV:-}"   # optional pinned revision hash
CONFIG_DIR="${CONFIG_DIR:-}"  # optional override
NO_BACKUP="${NO_BACKUP:-0}"   # set to 1 to disable backing up existing .jsonc before overwrite (still renames .json)

usage() {
  cat <<'EOF'
sync-opencode-user.sh

Env:
  GIST_USER=ControlNet
  GIST_ID=b10f23a707e3515e8fd215770e929b1a
  GIST_REV=<optional pinned revision hash>
  CONFIG_DIR=<optional override, default: ${XDG_CONFIG_HOME:-~/.config}/opencode>
  NO_BACKUP=1   (optional) do not backup existing .jsonc before overwrite

Examples:
  curl -fsSL <RAW_SCRIPT_URL> | bash
  GIST_REV=<rev> curl -fsSL <RAW_SCRIPT_URL> | bash
  CONFIG_DIR="$HOME/.config/opencode" curl -fsSL <RAW_SCRIPT_URL> | bash
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }

fetch() {
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -H 'Cache-Control: no-cache' -o "$out" "$url"
  else
    need_cmd wget
    wget -qO "$out" "$url"
  fi
  [[ -s "$out" ]] || { echo "Download failed or empty: $url" >&2; exit 1; }
}

ts() { date +"%Y%m%d-%H%M%S"; }

backup_and_install_jsonc() {
  local src="$1" dst="$2" stamp="$3"
  mkdir -p "$(dirname "$dst")"
  if [[ "$NO_BACKUP" != "1" && -f "$dst" ]]; then
    cp -a "$dst" "${dst}.bak-${stamp}"
  fi
  mv -f "$src" "$dst"
}

rename_json_if_exists() {
  local json_path="$1" stamp="$2"
  if [[ -f "$json_path" ]]; then
    local bak="${json_path}.bak-${stamp}"
    # avoid collision just in case
    if [[ -e "$bak" ]]; then
      bak="${bak}-$$"
    fi
    mv -f "$json_path" "$bak"
  fi
}

# Decide user-level config dir
if [[ -z "$CONFIG_DIR" ]]; then
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
  CONFIG_DIR="${XDG_CONFIG_HOME}/opencode"
fi
mkdir -p "$CONFIG_DIR"

# Build download URLs for the two config files
if [[ -n "$GIST_REV" ]]; then
  URL_OPENCODE="https://gist.githubusercontent.com/${GIST_USER}/${GIST_ID}/raw/${GIST_REV}/opencode.jsonc"
  URL_OMOC="https://gist.githubusercontent.com/${GIST_USER}/${GIST_ID}/raw/${GIST_REV}/oh-my-opencode.jsonc"
else
  # "latest" raw endpoint (follows redirects)
  URL_OPENCODE="https://gist.github.com/${GIST_USER}/${GIST_ID}/raw/opencode.jsonc"
  URL_OMOC="https://gist.github.com/${GIST_USER}/${GIST_ID}/raw/oh-my-opencode.jsonc"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

STAMP="$(ts)"
TMP_OPENCODE="$TMP_DIR/opencode.jsonc"
TMP_OMOC="$TMP_DIR/oh-my-opencode.jsonc"

echo "[1/3] Downloading:"
echo "      - $URL_OPENCODE"
echo "      - $URL_OMOC"

fetch "$URL_OPENCODE" "$TMP_OPENCODE"
fetch "$URL_OMOC" "$TMP_OMOC"

echo "[2/3] Installing to user-level config dir: $CONFIG_DIR"
backup_and_install_jsonc "$TMP_OPENCODE" "$CONFIG_DIR/opencode.jsonc" "$STAMP"
backup_and_install_jsonc "$TMP_OMOC" "$CONFIG_DIR/oh-my-opencode.jsonc" "$STAMP"

echo "[3/3] Renaming legacy .json (if exists) so only .jsonc remains active"
rename_json_if_exists "$CONFIG_DIR/opencode.json" "$STAMP"
rename_json_if_exists "$CONFIG_DIR/oh-my-opencode.json" "$STAMP"

echo "Done."
echo "Timestamp: $STAMP"
if [[ "$NO_BACKUP" != "1" ]]; then
  echo "Backups: *.bak-${STAMP}"
fi
