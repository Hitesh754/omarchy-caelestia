#!/usr/bin/env bash

set -euo pipefail

INSTALL_PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-caelestia"
INSTALL_DIR="$INSTALL_PREFIX/etc/xdg/quickshell/caelestia"

FOUND=0

for pid in $(pgrep -x qs 2>/dev/null || true); do
    [[ -r "/proc/$pid/cmdline" ]] || continue

    mapfile -d '' -t args < "/proc/$pid/cmdline"

    for ((i = 0; i < ${#args[@]}; i++)); do
        if [[ "${args[$i]}" == "-c" && "${args[$((i + 1))]:-}" == "caelestia" ]]; then
            echo "Stopping Omarchy-Caelestia: PID $pid"
            kill "$pid"
            FOUND=1
            break
        fi

        if [[ "${args[$i]}" == "$INSTALL_DIR" || "${args[$i]}" == "$INSTALL_DIR/shell.qml" ]]; then
            echo "Stopping Omarchy-Caelestia: PID $pid"
            kill "$pid"
            FOUND=1
            break
        fi
    done
done

if [[ "$FOUND" -eq 0 ]]; then
    echo "Caelestia is not running."
fi
