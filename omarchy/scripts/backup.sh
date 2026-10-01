#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="${1:-$HOME/.config/hypr/bindings.lua}"
BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-caelestia/backups"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "✗ Configuration file not found:"
    echo "  $CONFIG_FILE"
    exit 1
fi

mkdir -p "$BACKUP_ROOT"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP_FILE="$BACKUP_ROOT/bindings.lua.$TIMESTAMP"

cp --preserve=mode,ownership,timestamps "$CONFIG_FILE" "$BACKUP_FILE"

printf '%s\n' "$BACKUP_FILE"

echo "✓ Backup created:"
echo "  $BACKUP_FILE"
