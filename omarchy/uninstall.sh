#!/usr/bin/env bash
set -euo pipefail

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

INSTALL_PREFIX="$DATA_HOME/omarchy-caelestia"
SHELL_DIR="$INSTALL_PREFIX/etc/xdg/quickshell/caelestia"
LINK_PATH="$CONFIG_HOME/quickshell/caelestia"

BINDINGS_FILE="$CONFIG_HOME/hypr/bindings.lua"
STATE_DIR="$STATE_HOME/omarchy-caelestia"
BACKUP_STATE="$STATE_DIR/bindings-backup"
OWNED_HASH="$STATE_DIR/bindings-owned-hash"

TOGGLE_BIN="$HOME/.local/bin/omarchy-caelestia-toggle"
HOOK_FILE="$CONFIG_HOME/omarchy/hooks/theme-set.d/60-caelestia.sh"
CAELESTIA_CONFIG="$CONFIG_HOME/caelestia/shell.json"
CONFIG_OWNED_HASH="$STATE_DIR/caelestia-config-owned-hash"

BLOCK_START="-- BEGIN OMARCHY-CAELESTIA: launcher"
BLOCK_END="-- END OMARCHY-CAELESTIA: launcher"

die(){ echo "✗ $*" >&2; exit 1; }

command -v hyprctl >/dev/null || die "hyprctl is required"
command -v pgrep >/dev/null || die "pgrep is required"
[[ -f "$BINDINGS_FILE" ]] || die "Hyprland bindings not found: $BINDINGS_FILE"

echo "========================================"
echo " Omarchy + Caelestia Uninstaller"
echo "========================================"
echo

PIDS=()
for pid in $(pgrep -x qs 2>/dev/null || true); do
    [[ -r "/proc/$pid/cmdline" ]] || continue
    mapfile -d '' -t args < "/proc/$pid/cmdline"
    ours=0

    for ((i=0; i<${#args[@]}; i++)); do
        [[ "${args[$i]}" == "-c" &&
           "${args[$((i+1))]:-}" == "caelestia" ]] && ours=1
        [[ "${args[$i]}" == "$SHELL_DIR" ]] && ours=1
    done

    [[ "$ours" -eq 1 ]] && PIDS+=("$pid")
done

for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
done

sleep 1

for pid in "${PIDS[@]}"; do
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
done

if [[ -L "$LINK_PATH" ]]; then
    TARGET="$(readlink -f "$LINK_PATH" 2>/dev/null || true)"
    EXPECTED="$(readlink -f "$SHELL_DIR" 2>/dev/null || true)"
    [[ "$TARGET" == "$EXPECTED" ]] ||
        die "Quickshell link points somewhere unexpected; refusing to remove it."
    rm -f "$LINK_PATH"
elif [[ -d "$LINK_PATH" ]]; then
    [[ -z "$(find "$LINK_PATH" -mindepth 1 -maxdepth 1 -print -quit)" ]] ||
        die "$LINK_PATH is non-empty; refusing to touch it"
    rmdir "$LINK_PATH"
elif [[ -e "$LINK_PATH" ]]; then
    die "$LINK_PATH exists and is not a symlink"
fi

if [[ -f "$BACKUP_STATE" && -f "$OWNED_HASH" ]]; then
    EXPECTED_HASH="$(<"$OWNED_HASH")"
    CURRENT_HASH="$(sha256sum "$BINDINGS_FILE" | awk '{print $1}')"

    if [[ "$CURRENT_HASH" == "$EXPECTED_HASH" ]]; then
        BACKUP_FILE="$(<"$BACKUP_STATE")"
        [[ -f "$BACKUP_FILE" ]] ||
            die "Installer backup is missing: $BACKUP_FILE"

        cp --preserve=mode,ownership,timestamps "$BACKUP_FILE" "$BINDINGS_FILE"
        hyprctl reload >/dev/null
        echo "✓ Original Hyprland bindings restored."
    else
        echo "⚠ Hyprland bindings changed after installation."
        echo "  Preserving user changes and removing only the managed Caelestia block."

        python3 - "$BINDINGS_FILE" "$BLOCK_START" "$BLOCK_END" <<'PYREMOVE'
from pathlib import Path
import sys

path = Path(sys.argv[1])
start = sys.argv[2]
end = sys.argv[3]

text = path.read_text()

start_count = text.count(start)
end_count = text.count(end)

if start_count == 0 and end_count == 0:
    print("No managed Caelestia block found.")
    raise SystemExit(0)

if start_count != 1 or end_count != 1:
    raise SystemExit(
        f"Refusing to edit bindings: expected exactly one managed block, "
        f"found start={start_count}, end={end_count}."
    )

start_pos = text.index(start)
end_pos = text.index(end, start_pos)

end_line = text.find("\n", end_pos)
if end_line == -1:
    end_line = len(text)
else:
    end_line += 1

new_text = text[:start_pos] + text[end_line:]
path.write_text(new_text)

print("✓ Managed Caelestia bindings and autostart removed.")
PYREMOVE

        hyprctl reload >/dev/null
        echo "✓ Hyprland reloaded with user bindings preserved."
    fi
elif grep -Fq -- "$BLOCK_START" "$BINDINGS_FILE" ||
     grep -Fq -- "$BLOCK_END" "$BINDINGS_FILE"; then
    echo "⚠ Caelestia binding exists but installer ownership cannot be proven."
    echo "  Leaving the bindings untouched."
fi

[[ "$INSTALL_PREFIX" == "$DATA_HOME/omarchy-caelestia" ]] ||
    die "Unsafe installation path"

if [[ -e "$INSTALL_PREFIX" ]]; then
    [[ -f "$INSTALL_PREFIX/lib/caelestia/version" ]] ||
        die "$INSTALL_PREFIX is not a recognized Caelestia installation; refusing to remove it."
    rm -rf -- "$INSTALL_PREFIX"
fi

# Helpers installed by install-extras.sh. Files are only removed when they are
# ours: the toggle and hook by their header, the config only if unedited.
if [[ -f "$TOGGLE_BIN" ]] && grep -q "omarchy-caelestia" "$TOGGLE_BIN"; then
    rm -f "$TOGGLE_BIN"
    echo "✓ omarchy-caelestia-toggle removed."
fi

if [[ -f "$HOOK_FILE" ]] && grep -q "omarchy-caelestia" "$HOOK_FILE"; then
    rm -f "$HOOK_FILE"
    echo "✓ Theme sync hook removed."
fi

if [[ -f "$CAELESTIA_CONFIG" && -f "$CONFIG_OWNED_HASH" ]]; then
    if [[ "$(sha256sum "$CAELESTIA_CONFIG" | awk '{print $1}')" == "$(<"$CONFIG_OWNED_HASH")" ]]; then
        rm -f "$CAELESTIA_CONFIG"
        rmdir "$(dirname "$CAELESTIA_CONFIG")" 2>/dev/null || true
        echo "✓ Default Caelestia config removed."
    else
        echo "⚠ $CAELESTIA_CONFIG was edited; leaving it in place."
    fi
fi

rm -f "$BACKUP_STATE" "$OWNED_HASH" "$CONFIG_OWNED_HASH" \
    "$STATE_DIR/disabled" "$STATE_DIR/caelestia.log"

if [[ -d "$STATE_DIR" ]] &&
   [[ -z "$(find "$STATE_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    rmdir "$STATE_DIR"
fi

echo
echo "========================================"
echo " Uninstallation complete"
echo "========================================"
echo
echo "Omarchy's /usr/share/omarchy/shell was not modified."
