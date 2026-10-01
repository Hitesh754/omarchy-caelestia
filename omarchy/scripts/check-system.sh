#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_DIR="$PROJECT_ROOT"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_PREFIX="$DATA_HOME/omarchy-caelestia"
INSTALL_DIR="$INSTALL_PREFIX/etc/xdg/quickshell/caelestia"

echo "========================================"
echo " Omarchy + Caelestia System Check"
echo "========================================"
echo

fail=0

check_command() {
    local name="$1"
    local command="$2"

    if command -v "$command" >/dev/null 2>&1; then
        echo "✓ $name: $(command -v "$command")"
    else
        echo "✗ $name: not found"
        fail=1
    fi
}

check_command "pacman" pacman
check_command "Hyprland" hyprctl
check_command "Quickshell" qs
check_command "CMake" cmake
check_command "Ninja" ninja
check_command "Git" git

echo

if pgrep -f 'quickshell.*(/usr/share/omarchy/shell|omarchy/shell)' >/dev/null 2>&1; then
    echo "✓ Omarchy shell: running"
else
    echo "⚠ Omarchy shell: not detected"
fi

echo

CAELESTIA_RUNNING=0
CAELESTIA_PID=""

for pid in $(pgrep -x qs 2>/dev/null || true); do
    [[ -r "/proc/$pid/cmdline" ]] || continue

    mapfile -d '' -t args < "/proc/$pid/cmdline"

    for ((i = 0; i < ${#args[@]}; i++)); do
        if [[ "${args[$i]}" == "-c" && "${args[$((i + 1))]:-}" == "caelestia" ]]; then
            CAELESTIA_RUNNING=1
            CAELESTIA_PID="$pid"
            break 2
        fi
    done
done

if (( CAELESTIA_RUNNING )); then
    echo "✓ Caelestia shell: running"
    echo "  PID: $CAELESTIA_PID"
else
    echo "⚠ Caelestia shell: not running"
fi

echo

if [[ -d "$SOURCE_DIR" ]]; then
    echo "✓ Caelestia source: found"
    echo "  $SOURCE_DIR"
else
    echo "✗ Caelestia source: not found"
    echo "  $SOURCE_DIR"
    fail=1
fi

if [[ -f "$INSTALL_DIR/shell.qml" ]]; then
    echo "✓ Installed Caelestia shell: found"
else
    echo "⚠ Installed Caelestia shell: not found"
fi

QUICKSHELL_LINK="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"

if [[ -L "$QUICKSHELL_LINK" ]]; then
    echo "✓ Quickshell Caelestia link: configured"
    echo "  $QUICKSHELL_LINK → $(readlink -f "$QUICKSHELL_LINK")"
elif [[ -e "$QUICKSHELL_LINK" ]]; then
    echo "⚠ Quickshell Caelestia path exists but is not a symlink"
else
    echo "⚠ Quickshell Caelestia link: not configured"
fi

if [[ -f "$HOME/.config/hypr/bindings.lua" ]]; then
    echo "✓ Hyprland user bindings: found"
else
    echo "⚠ Hyprland user bindings: not found"
fi

echo

if (( fail != 0 )); then
    echo "System check failed."
    exit 1
fi

echo "System check passed."
