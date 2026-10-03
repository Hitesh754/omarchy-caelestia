#!/usr/bin/env bash
# Install the Omarchy-side helpers for Caelestia:
#   - omarchy-caelestia-toggle (start/stop/toggle, used by autostart and keybind)
#   - theme-set hook that syncs Caelestia's colours/wallpaper with the Omarchy theme
#   - default Caelestia config that leaves the wallpaper to Omarchy, so Omarchy
#     backgrounds and motion-wallpaper plugins stay visible
# Safe to run repeatedly; used by both install.sh and update.sh.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

STATE_DIR="$STATE_HOME/omarchy-caelestia"
TOGGLE_BIN="$HOME/.local/bin/omarchy-caelestia-toggle"
HOOK_FILE="$CONFIG_HOME/omarchy/hooks/theme-set.d/60-caelestia.sh"
CAELESTIA_CONFIG="$CONFIG_HOME/caelestia/shell.json"
CONFIG_OWNED_HASH="$STATE_DIR/caelestia-config-owned-hash"

info(){ echo "==> $*"; }

mkdir -p "$STATE_DIR" "$(dirname "$TOGGLE_BIN")" "$(dirname "$HOOK_FILE")"

info "Installing omarchy-caelestia-toggle"
install -m 755 "$PROJECT_ROOT/omarchy/scripts/caelestia-toggle.sh" "$TOGGLE_BIN"

info "Installing Omarchy theme sync hook"
install -m 755 "$PROJECT_ROOT/omarchy/hooks/theme-set-caelestia.sh" "$HOOK_FILE"

THEME_NAME_FILE="$STATE_HOME/omarchy/current/theme.name"
THEME_NAME="omarchy"
[[ -f "$THEME_NAME_FILE" ]] && THEME_NAME="$(<"$THEME_NAME_FILE")"
"$HOOK_FILE" "$THEME_NAME" || echo "⚠ Theme sync failed; Caelestia keeps its default colours."

if [[ -e "$CAELESTIA_CONFIG" ]]; then
    echo "  Keeping existing $CAELESTIA_CONFIG"
    echo "  Set background.wallpaperEnabled to false there to show Omarchy/motion wallpapers."
else
    info "Writing default Caelestia config (wallpaper handled by Omarchy)"
    mkdir -p "$(dirname "$CAELESTIA_CONFIG")"
    cat > "$CAELESTIA_CONFIG" <<'JSON'
{
  "background": {
    "wallpaperEnabled": false
  }
}
JSON
    sha256sum "$CAELESTIA_CONFIG" | awk '{print $1}' > "$CONFIG_OWNED_HASH"
fi
