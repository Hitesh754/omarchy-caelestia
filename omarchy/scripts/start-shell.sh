#!/usr/bin/env bash

set -euo pipefail

INSTALL_PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-caelestia"
INSTALL_DIR="$INSTALL_PREFIX/etc/xdg/quickshell/caelestia"
SHELL_FILE="$INSTALL_DIR/shell.qml"
QML_DIR="$INSTALL_PREFIX/lib/qt6/qml"
LIB_DIR="$INSTALL_PREFIX/lib/caelestia"

echo "==> Starting Omarchy-Caelestia"
echo

if [[ ! -f "$SHELL_FILE" ]]; then
    echo "✗ Installed Caelestia shell not found:"
    echo "  $SHELL_FILE"
    exit 1
fi

if [[ ! -d "$QML_DIR/Caelestia" ]]; then
    echo "✗ Installed Caelestia QML modules not found:"
    echo "  $QML_DIR/Caelestia"
    exit 1
fi

if [[ ! -d "$LIB_DIR" ]]; then
    echo "✗ Caelestia library directory not found:"
    echo "  $LIB_DIR"
    exit 1
fi

# Detect only our Caelestia shell.
# We inspect the individual argv entries instead of matching
# the entire command line. This avoids touching Omarchy's shell.

RUNNING_PID=""

for pid in $(pgrep -x qs 2>/dev/null || true); do
    [[ -r "/proc/$pid/cmdline" ]] || continue

    mapfile -d '' -t args < "/proc/$pid/cmdline"

    for ((i = 0; i < ${#args[@]}; i++)); do
        if [[ "${args[$i]}" == "-c" && "${args[$((i + 1))]:-}" == "caelestia" ]]; then
            RUNNING_PID="$pid"
            break 2
        fi

        if [[ "${args[$i]}" == "$INSTALL_DIR" || "${args[$i]}" == "$SHELL_FILE" ]]; then
            RUNNING_PID="$pid"
            break 2
        fi
    done
done

if [[ -n "$RUNNING_PID" ]]; then
    echo "✓ Caelestia is already running."
    echo "  PID: $RUNNING_PID"
    echo "  Shell: $INSTALL_DIR"
    exit 0
fi

echo "Installed shell:"
echo "  $INSTALL_DIR"
echo

echo "QML modules:"
echo "  $QML_DIR"
echo

echo "Libraries:"
echo "  $LIB_DIR"
echo

export QS_ICON_THEME="Adwaita"
export CAELESTIA_LIB_DIR="$LIB_DIR"

export QML2_IMPORT_PATH="$QML_DIR"

echo "==> Launching Caelestia"
echo

exec qs -c caelestia
