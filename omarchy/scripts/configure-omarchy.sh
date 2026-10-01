#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="$HOME/.config/hypr/bindings.lua"
BACKUP_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backup.sh"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-caelestia"
BACKUP_STATE_FILE="$STATE_DIR/bindings-backup"

MARKER_START="-- BEGIN OMARCHY-CAELESTIA: launcher"
MARKER_END="-- END OMARCHY-CAELESTIA: launcher"

CAELESTIA_BLOCK='-- BEGIN OMARCHY-CAELESTIA: launcher
hl.unbind("SUPER + SPACE")
hl.bind(
    "SUPER + SPACE",
    hl.dsp.exec_cmd("qs ipc -c caelestia call drawers toggle launcher"),
    { description = "Caelestia launcher" }
)
-- END OMARCHY-CAELESTIA: launcher'

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "✗ Hyprland bindings file not found:"
    echo "  $CONFIG_FILE"
    exit 1
fi

if ! command -v hyprctl >/dev/null 2>&1; then
    echo "✗ hyprctl is not available."
    exit 1
fi

if grep -Fq -- "$CAELESTIA_BLOCK" "$CONFIG_FILE"; then
    echo "✓ Caelestia launcher binding is already configured."
    exit 0
fi

# The integration may have been configured manually before the installer
# existed. Detect that exact unmarked binding so we replace it rather than
# creating a duplicate SUPER + SPACE binding.
if grep -Fq 'hl.dsp.exec_cmd("qs ipc -c caelestia call drawers toggle launcher")' "$CONFIG_FILE"; then
    echo "✓ Existing Caelestia launcher binding detected."
fi

echo "==> Backing up Hyprland bindings"
BACKUP_OUTPUT="$("$BACKUP_SCRIPT" "$CONFIG_FILE")"
printf '%s\n' "$BACKUP_OUTPUT"

BACKUP_FILE="$(printf '%s\n' "$BACKUP_OUTPUT" | awk '/^\/.*bindings\.lua\./ { print; exit }')"

if [[ -z "$BACKUP_FILE" || ! -f "$BACKUP_FILE" ]]; then
    echo "✗ Could not determine the backup file."
    exit 1
fi

mkdir -p "$STATE_DIR"

TMP_FILE="$(mktemp "${CONFIG_FILE}.caelestia.XXXXXX")"

cleanup() {
    rm -f "$TMP_FILE"
}

trap cleanup EXIT

python - "$CONFIG_FILE" "$TMP_FILE" "$MARKER_START" "$MARKER_END" <<'PY'
from pathlib import Path
import sys

config = Path(sys.argv[1])
tmp = Path(sys.argv[2])
start = sys.argv[3]
end = sys.argv[4]

text = config.read_text()

block = '''-- BEGIN OMARCHY-CAELESTIA: launcher
hl.unbind("SUPER + SPACE")
hl.bind(
    "SUPER + SPACE",
    hl.dsp.exec_cmd("qs ipc -c caelestia call drawers toggle launcher"),
    { description = "Caelestia launcher" }
)
-- END OMARCHY-CAELESTIA: launcher'''

old_manual = '''hl.unbind("SUPER + SPACE")
hl.bind(
    "SUPER + SPACE",
    hl.dsp.exec_cmd("qs ipc -c caelestia call drawers toggle launcher"),
    { description = "Caelestia launcher" }
)'''

if start in text and end in text:
    before, remainder = text.split(start, 1)
    _, after = remainder.split(end, 1)
    text = before.rstrip() + "\n\n" + block + after
elif old_manual in text:
    text = text.replace(old_manual, block, 1)
else:
    text = text.rstrip() + "\n\n" + block + "\n"

tmp.write_text(text)
PY

cp --preserve=mode,ownership,timestamps "$TMP_FILE" "$CONFIG_FILE"

echo
echo "==> Reloading Hyprland"
if ! hyprctl reload >/dev/null; then
    echo "✗ Hyprland reload failed."
    cp --preserve=mode,ownership,timestamps "$BACKUP_FILE" "$CONFIG_FILE"
    hyprctl reload >/dev/null 2>&1 || true
    rm -f "$BACKUP_STATE_FILE"
    exit 1
fi

sleep 1

echo "==> Checking Hyprland configuration"
CONFIG_ERRORS="$(hyprctl configerrors 2>&1 || true)"

if [[ -n "$CONFIG_ERRORS" && "$CONFIG_ERRORS" != "no errors" && "$CONFIG_ERRORS" != "No errors" ]]; then
    echo "✗ Hyprland reported configuration errors:"
    printf '%s\n' "$CONFIG_ERRORS"
    echo
    echo "==> Restoring previous bindings"
    cp --preserve=mode,ownership,timestamps "$BACKUP_FILE" "$CONFIG_FILE"
    hyprctl reload >/dev/null 2>&1 || true
    rm -f "$BACKUP_STATE_FILE"
    echo "✓ Previous bindings restored."
    exit 1
fi

printf '%s\n' "$BACKUP_FILE" > "$BACKUP_STATE_FILE"

echo "✓ Hyprland configuration is valid."
echo "✓ Caelestia launcher binding configured."
