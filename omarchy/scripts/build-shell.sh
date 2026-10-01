#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_DIR="$PROJECT_ROOT"
BUILD_DIR="$SOURCE_DIR/build"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
mkdir -p "$DATA_HOME"

STAGING_ROOT="$(mktemp -d "$DATA_HOME/.omarchy-caelestia-staging.XXXXXX")"
STAGING_PREFIX="$STAGING_ROOT/omarchy-caelestia"

STAGING_INFO="$DATA_HOME/.omarchy-caelestia-staging-path"

cleanup() {
    rm -rf "$STAGING_ROOT"

    if [[ -f "$STAGING_INFO" ]]; then
        rm -f "$STAGING_INFO"
    fi
}

trap cleanup EXIT

echo "==> Omarchy-Caelestia build"
echo

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "✗ Caelestia source directory not found:"
    echo "  $SOURCE_DIR"
    exit 1
fi

echo "Source:"
echo "  $SOURCE_DIR"
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
echo "==> Installing into staging area"

mkdir -p "$STAGING_PREFIX"

cmake \
    --install "$BUILD_DIR" \
    --prefix "$STAGING_PREFIX"

echo
echo "==> Validating staged installation"

SHELL_FILE="$STAGING_PREFIX/etc/xdg/quickshell/caelestia/shell.qml"
QML_DIR="$STAGING_PREFIX/lib/qt6/qml/Caelestia"
LIB_DIR="$STAGING_PREFIX/lib/caelestia"
VERSION_FILE="$LIB_DIR/version"

if [[ ! -f "$SHELL_FILE" ]]; then
    echo "✗ shell.qml missing"
    exit 1
fi

if [[ ! -d "$QML_DIR" ]]; then
    echo "✗ Caelestia QML modules missing"
    exit 1
fi

if [[ ! -d "$LIB_DIR" ]]; then
    echo "✗ Caelestia libraries missing"
    exit 1
fi

if [[ ! -f "$VERSION_FILE" ]]; then
    echo "✗ Caelestia version information missing"
    exit 1
fi

echo "✓ shell.qml"
echo "✓ QML modules"
echo "✓ Caelestia libraries"
echo "✓ version information"

printf '%s\n' "$STAGING_PREFIX" > "$STAGING_INFO"

echo
echo "✓ Build and staging successful."
echo
echo "Staged installation:"
echo "  $STAGING_PREFIX"
echo
echo "Staging information:"
echo "  $STAGING_INFO"
echo

# Keep the staging directory and staging-info file alive.
trap - EXIT
