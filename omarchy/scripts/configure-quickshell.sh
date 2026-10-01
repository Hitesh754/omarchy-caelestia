#!/usr/bin/env bash

set -euo pipefail

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

INSTALL_PREFIX="$DATA_HOME/omarchy-caelestia"
SHELL_DIR="$INSTALL_PREFIX/etc/xdg/quickshell/caelestia"

QUICKSHELL_DIR="$CONFIG_HOME/quickshell"
LINK_PATH="$QUICKSHELL_DIR/caelestia"

echo "==> Configuring Quickshell integration"
echo

if [[ ! -d "$SHELL_DIR" ]]; then
    echo "✗ Caelestia shell directory not found:"
    echo "  $SHELL_DIR"
    exit 1
fi

mkdir -p "$QUICKSHELL_DIR"

if [[ -L "$LINK_PATH" ]]; then
    CURRENT_TARGET="$(readlink -f "$LINK_PATH" 2>/dev/null || true)"
    EXPECTED_TARGET="$(readlink -f "$SHELL_DIR")"

    if [[ "$CURRENT_TARGET" == "$EXPECTED_TARGET" ]]; then
        echo "✓ Caelestia Quickshell symlink already configured."
        echo "  $LINK_PATH"
        echo "  → $CURRENT_TARGET"
        exit 0
    fi

    echo "✗ Existing Caelestia Quickshell symlink points elsewhere:"
    echo "  $LINK_PATH"
    echo "  → $CURRENT_TARGET"
    echo
    echo "Refusing to overwrite it."
    exit 1
fi

if [[ -e "$LINK_PATH" ]]; then
    echo "✗ Existing Quickshell configuration found:"
    echo "  $LINK_PATH"
    echo
    echo "It is not a symlink, so it will not be overwritten."
    exit 1
fi

ln -s "$SHELL_DIR" "$LINK_PATH"

echo "✓ Caelestia Quickshell integration configured."
echo
echo "Configuration:"
echo "  $LINK_PATH"
echo "  → $SHELL_DIR"
