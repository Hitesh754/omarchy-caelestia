#!/usr/bin/env bash
# Start, stop or toggle the Caelestia shell (omarchy-caelestia).
# Usage: omarchy-caelestia-toggle [toggle|on|off|start]
#   toggle  stop if running, start if not (default)
#   on/off  force a state; the choice persists across logins
#   start   start at login unless it was turned off

PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-caelestia"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-caelestia"
DISABLED_FLAG="$STATE_DIR/disabled"
LOG_FILE="$STATE_DIR/caelestia.log"

mkdir -p "$STATE_DIR"

running_pid() {
    pgrep -x -f "qs -c caelestia" | head -n1
}

notify() {
    command -v omarchy-notification-send >/dev/null &&
        omarchy-notification-send -u low "$1" >/dev/null 2>&1 &
}

start() {
    [[ -n "$(running_pid)" ]] && return 0
    [[ -f "$PREFIX/etc/xdg/quickshell/caelestia/shell.qml" ]] || {
        echo "Caelestia is not installed in $PREFIX" >&2
        return 1
    }
    QS_ICON_THEME=Adwaita \
    CAELESTIA_LIB_DIR="$PREFIX/lib/caelestia" \
    QML2_IMPORT_PATH="$PREFIX/lib/qt6/qml" \
        setsid -f qs -c caelestia >"$LOG_FILE" 2>&1 </dev/null
}

stop() {
    local pid
    pid="$(running_pid)" || true
    [[ -n "$pid" ]] || return 0
    kill "$pid" 2>/dev/null
    for _ in {1..20}; do
        kill -0 "$pid" 2>/dev/null || return 0
        sleep 0.1
    done
    kill -9 "$pid" 2>/dev/null
}

case "${1:-toggle}" in
    start)
        [[ -f "$DISABLED_FLAG" ]] || start
        ;;
    on)
        rm -f "$DISABLED_FLAG"
        start
        ;;
    off)
        touch "$DISABLED_FLAG"
        stop
        ;;
    toggle)
        if [[ -n "$(running_pid)" ]]; then
            touch "$DISABLED_FLAG"
            stop
            notify "Caelestia off"
        else
            rm -f "$DISABLED_FLAG"
            start
            notify "Caelestia on"
        fi
        ;;
    *)
        echo "Usage: $(basename "$0") [toggle|on|off|start]" >&2
        exit 1
        ;;
esac
