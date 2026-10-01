#!/usr/bin/env bash

set -euo pipefail

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

INSTALL_PREFIX="$DATA_HOME/omarchy-caelestia"
PREVIOUS_PREFIX="$DATA_HOME/omarchy-caelestia.previous"

STAGING_PREFIX="${1:-}"

if [[ -z "$STAGING_PREFIX" ]]; then
    echo "✗ No staging directory supplied."
    echo
    echo "Usage:"
    echo "  ./scripts/activate-shell.sh /path/to/staged/omarchy-caelestia"
    exit 1
fi

if [[ ! -d "$STAGING_PREFIX" ]]; then
    echo "✗ Staging directory does not exist:"
    echo "  $STAGING_PREFIX"
    exit 1
fi

SHELL_FILE="$STAGING_PREFIX/etc/xdg/quickshell/caelestia/shell.qml"
QML_DIR="$STAGING_PREFIX/lib/qt6/qml/Caelestia"
LIB_DIR="$STAGING_PREFIX/lib/caelestia"
VERSION_FILE="$LIB_DIR/version"

echo "==> Activating Omarchy-Caelestia"
echo

echo "Staged version:"
echo "  $STAGING_PREFIX"
echo

echo "Target:"
echo "  $INSTALL_PREFIX"
echo

# Final safety validation before touching the current installation.

if [[ ! -f "$SHELL_FILE" ]]; then
    echo "✗ Staged shell.qml is missing."
    exit 1
fi

if [[ ! -d "$QML_DIR" ]]; then
    echo "✗ Staged Caelestia QML modules are missing."
    exit 1
fi

if [[ ! -d "$LIB_DIR" ]]; then
    echo "✗ Staged Caelestia libraries are missing."
    exit 1
fi

if [[ ! -f "$VERSION_FILE" ]]; then
    echo "✗ Staged version information is missing."
    exit 1
fi

PARENT_DIR="$(dirname "$INSTALL_PREFIX")"
mkdir -p "$PARENT_DIR"

# A previous rollback copy must not already exist.
# This prevents accidentally destroying the last known-good version.
if [[ -e "$PREVIOUS_PREFIX" ]]; then
    echo "✗ A previous installation already exists:"
    echo "  $PREVIOUS_PREFIX"
    echo
    echo "The previous update may not have completed."
    echo "Do not overwrite it automatically."
    exit 1
fi

# Preserve the currently installed version.
if [[ -e "$INSTALL_PREFIX" ]]; then
    echo "==> Preserving current installation"

    mv "$INSTALL_PREFIX" "$PREVIOUS_PREFIX"

    echo "✓ Previous installation saved:"
    echo "  $PREVIOUS_PREFIX"
else
    echo "No existing installation found."
fi

# Activate the new version.
if ! mv "$STAGING_PREFIX" "$INSTALL_PREFIX"; then
    echo "✗ Failed to activate new installation."
    echo

    if [[ -e "$PREVIOUS_PREFIX" ]]; then
        echo "==> Restoring previous installation"

        mv "$PREVIOUS_PREFIX" "$INSTALL_PREFIX"

        echo "✓ Previous installation restored."
    fi

    exit 1
fi

echo
echo "✓ New installation activated."
echo
echo "Installation:"
echo "  $INSTALL_PREFIX"
echo

if [[ -e "$PREVIOUS_PREFIX" ]]; then
    echo "Rollback copy:"
    echo "  $PREVIOUS_PREFIX"
else
    echo "Rollback copy:"
    echo "  none (initial installation)"
fi

echo
echo "Activation successful."
