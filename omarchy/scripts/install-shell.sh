#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_DIR="$PROJECT_ROOT"
BUILD_DIR="$SOURCE_DIR/build"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_PREFIX="$DATA_HOME/omarchy-caelestia"
PREVIOUS_PREFIX="$DATA_HOME/omarchy-caelestia.previous"

STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/omarchy-caelestia-install.XXXXXX")"
STAGING_PREFIX="$STAGING_ROOT/omarchy-caelestia"

cleanup() {
    rm -rf "$STAGING_ROOT"
}

trap cleanup EXIT

echo "==> Omarchy-Caelestia shell installation"
echo

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "✗ Caelestia source directory not found:"
    echo "  $SOURCE_DIR"
    exit 1
fi

echo "Source:"
echo "  $SOURCE_DIR"
echo

echo "Installation target:"
echo "  $INSTALL_PREFIX"
echo

echo "==> Configuring CMake"

cmake \
    -S "$SOURCE_DIR" \
    -B "$BUILD_DIR" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release

echo
echo "==> Building Caelestia"

cmake --build "$BUILD_DIR"

echo
echo "==> Installing to temporary staging directory"

mkdir -p "$STAGING_PREFIX"

cmake \
    --install "$BUILD_DIR" \
    --prefix "$STAGING_PREFIX"

echo
echo "==> Verifying staged installation"

SHELL_FILE="$STAGING_PREFIX/etc/xdg/quickshell/caelestia/shell.qml"
QML_DIR="$STAGING_PREFIX/lib/qt6/qml/Caelestia"
LIB_DIR="$STAGING_PREFIX/lib/caelestia"
VERSION_FILE="$LIB_DIR/version"

if [[ ! -f "$SHELL_FILE" ]]; then
    echo "✗ Installed shell.qml was not found."
    exit 1
fi

if [[ ! -d "$QML_DIR" ]]; then
    echo "✗ Installed Caelestia QML modules were not found."
    exit 1
fi

if [[ ! -d "$LIB_DIR" ]]; then
    echo "✗ Caelestia library directory was not found."
    exit 1
fi

if [[ ! -f "$VERSION_FILE" ]]; then
    echo "✗ Caelestia version information was not found."
    exit 1
fi

echo "✓ shell.qml"
echo "✓ QML modules"
echo "✓ Caelestia libraries"
echo "✓ version information"

echo
echo "==> Activating installation"

PARENT_DIR="$(dirname "$INSTALL_PREFIX")"
mkdir -p "$PARENT_DIR"

# Remove an old rollback copy.
rm -rf "$PREVIOUS_PREFIX"

# Preserve the currently installed version if one exists.
if [[ -d "$INSTALL_PREFIX" ]]; then
    echo "Preserving current installation:"
    echo "  $PREVIOUS_PREFIX"
    mv "$INSTALL_PREFIX" "$PREVIOUS_PREFIX"
fi

# Activate the fully validated staged installation.
if ! mv "$STAGING_PREFIX" "$INSTALL_PREFIX"; then
    echo "✗ Failed to activate new installation."

    if [[ -d "$PREVIOUS_PREFIX" ]]; then
        mv "$PREVIOUS_PREFIX" "$INSTALL_PREFIX"
    fi

    exit 1
fi

echo
echo "Installation successful."
echo
echo "Installation prefix:"
echo "  $INSTALL_PREFIX"
echo
echo "Previous installation:"
echo "  $PREVIOUS_PREFIX"
echo
echo "Shell:"
echo "  $INSTALL_PREFIX/etc/xdg/quickshell/caelestia/shell.qml"
echo
echo "QML:"
echo "  $INSTALL_PREFIX/lib/qt6/qml"
echo
echo "Libraries:"
echo "  $INSTALL_PREFIX/lib/caelestia"
