#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

INSTALL_PREFIX="$DATA_HOME/omarchy-caelestia"
PREVIOUS_PREFIX="$DATA_HOME/omarchy-caelestia.previous"
STAGING_INFO="$DATA_HOME/.omarchy-caelestia-staging-path"

SHELL_DIR="$INSTALL_PREFIX/etc/xdg/quickshell/caelestia"
SHELL_FILE="$SHELL_DIR/shell.qml"

STAGING_PREFIX=""

cleanup() {
    if [[ -n "$STAGING_PREFIX" && -d "$STAGING_PREFIX" ]]; then
        echo
        echo "==> Cleaning staging directory"
        rm -rf "$STAGING_PREFIX"
    fi

    rm -f "$STAGING_INFO"
}

trap cleanup EXIT

echo "==> Omarchy-Caelestia update"
echo

# ------------------------------------------------------------
# PRE-FLIGHT
# ------------------------------------------------------------

if [[ ! -f "$PROJECT_ROOT/CMakeLists.txt" ]]; then
    echo "✗ Caelestia source directory not found:"
    echo "  $PROJECT_ROOT"
    exit 1
fi

if [[ ! -f "$SHELL_FILE" ]]; then
    echo "✗ No existing Caelestia installation found."
    echo
    echo "Run:"
    echo "  ./install.sh"
    exit 1
fi

if [[ -e "$PREVIOUS_PREFIX" ]]; then
    echo "✗ A previous rollback copy already exists:"
    echo "  $PREVIOUS_PREFIX"
    echo
    echo "The previous update may not have completed."
    echo "Resolve that state before running another update."
    exit 1
fi

if [[ -e "$STAGING_INFO" ]]; then
    echo "✗ A previous staging operation left state behind:"
    echo "  $STAGING_INFO"
    echo
    echo "Remove the stale staging state only after verifying"
    echo "that no build/update is currently running."
    exit 1
fi

echo "Current installation:"
echo "  $INSTALL_PREFIX"
echo

# ------------------------------------------------------------
# STEP 1 — BUILD
# ------------------------------------------------------------

echo "==> Step 1/5: Building and validating"
echo

"$PROJECT_ROOT/omarchy/scripts/build-shell.sh"

if [[ ! -f "$STAGING_INFO" ]]; then
    echo
    echo "✗ Build completed without producing staging information."
    exit 1
fi

STAGING_PREFIX="$(<"$STAGING_INFO")"

if [[ -z "$STAGING_PREFIX" || ! -d "$STAGING_PREFIX" ]]; then
    echo
    echo "✗ Staging directory is invalid:"
    echo "  $STAGING_PREFIX"
    exit 1
fi

echo
echo "✓ New version staged successfully."
echo "  $STAGING_PREFIX"

# ------------------------------------------------------------
# STEP 2 — STOP CURRENT SHELL
# ------------------------------------------------------------

echo
echo "==> Step 2/5: Stopping Caelestia"
echo

"$PROJECT_ROOT/omarchy/scripts/stop-shell.sh"

sleep 1

RUNNING_PID=""

for pid in $(pgrep -x qs 2>/dev/null || true); do
    [[ -r "/proc/$pid/cmdline" ]] || continue

    mapfile -d '' -t args < "/proc/$pid/cmdline"

    for ((i = 0; i < ${#args[@]}; i++)); do
        if [[ "${args[$i]}" == "-c" && "${args[$((i + 1))]:-}" == "caelestia" ]]; then
            RUNNING_PID="$pid"
            break 2
        fi

        if [[ "${args[$i]}" == "$SHELL_DIR" || "${args[$i]}" == "$SHELL_FILE" ]]; then
            RUNNING_PID="$pid"
            break 2
        fi
    done
done

if [[ -n "$RUNNING_PID" ]]; then
    echo "✗ Caelestia is still running."
    echo "  PID: $RUNNING_PID"
    echo
    echo "The update will not continue."
    exit 1
fi

echo "✓ Caelestia stopped."

# ------------------------------------------------------------
# STEP 3 — ACTIVATE
# ------------------------------------------------------------

echo
echo "==> Step 3/5: Activating new version"
echo

if ! "$PROJECT_ROOT/omarchy/scripts/activate-shell.sh" "$STAGING_PREFIX"; then
    echo
    echo "✗ Activation failed."
    echo "Attempting to restore the previous installation."

    if [[ -d "$PREVIOUS_PREFIX" && ! -d "$INSTALL_PREFIX" ]]; then
        mv "$PREVIOUS_PREFIX" "$INSTALL_PREFIX"
        echo "✓ Previous installation restored."
    fi

    exit 1
fi

# The staging directory has now become the live installation.
STAGING_PREFIX=""

echo
echo "✓ New version activated."

# ------------------------------------------------------------
# STEP 3.5 — CONFIGURE QUICKSHELL
# ------------------------------------------------------------

echo
echo "==> Configuring Quickshell integration"
echo

if ! "$PROJECT_ROOT/omarchy/scripts/configure-quickshell.sh"; then
    echo
    echo "✗ Quickshell integration failed."
    echo
    echo "==> Rolling back"

    if [[ -d "$INSTALL_PREFIX" ]]; then
        rm -rf "$INSTALL_PREFIX"
    fi

    if [[ -d "$PREVIOUS_PREFIX" ]]; then
        mv "$PREVIOUS_PREFIX" "$INSTALL_PREFIX"
        echo "✓ Previous installation restored."
    else
        echo "✗ Rollback copy is missing:"
        echo "  $PREVIOUS_PREFIX"
        exit 1
    fi

    echo
    echo "==> Starting previous Caelestia"

    "$PROJECT_ROOT/omarchy/scripts/start-shell.sh"

    echo
    echo "✗ Update failed."
    echo "✓ Previous version restored."
    exit 1
fi

echo "✓ Quickshell integration configured."

# ------------------------------------------------------------
# STEP 4 — START
# ------------------------------------------------------------

echo
echo "==> Step 4/5: Starting new Caelestia"
echo

START_LOG="$(mktemp)"

"$PROJECT_ROOT/omarchy/scripts/start-shell.sh" >"$START_LOG" 2>&1 &
START_PID=$!

echo "Waiting for Caelestia to start..."

RUNNING_PID=""

for attempt in {1..20}; do
    RUNNING_PID=""

    for pid in $(pgrep -x qs 2>/dev/null || true); do
        [[ -r "/proc/$pid/cmdline" ]] || continue

        mapfile -d '' -t args < "/proc/$pid/cmdline"

        for ((i = 0; i < ${#args[@]}; i++)); do
            if [[ "${args[$i]}" == "-c" && "${args[$((i + 1))]:-}" == "caelestia" ]]; then
                RUNNING_PID="$pid"
                break 2
            fi

            if [[ "${args[$i]}" == "$SHELL_DIR" || "${args[$i]}" == "$SHELL_FILE" ]]; then
                RUNNING_PID="$pid"
                break 2
            fi
        done
    done

    if [[ -n "$RUNNING_PID" ]]; then
        break
    fi

    sleep 0.5
done

if [[ -s "$START_LOG" ]]; then
    cat "$START_LOG"
fi

rm -f "$START_LOG"

# ------------------------------------------------------------
# STEP 5 — VERIFY
# ------------------------------------------------------------

echo
echo "==> Step 5/5: Verifying new installation"
echo

RUNNING_PID=""

for pid in $(pgrep -x qs 2>/dev/null || true); do
    [[ -r "/proc/$pid/cmdline" ]] || continue

    mapfile -d '' -t args < "/proc/$pid/cmdline"

    for ((i = 0; i < ${#args[@]}; i++)); do
        if [[ "${args[$i]}" == "-c" && "${args[$((i + 1))]:-}" == "caelestia" ]]; then
            RUNNING_PID="$pid"
            break 2
        fi

        if [[ "${args[$i]}" == "$SHELL_DIR" || "${args[$i]}" == "$SHELL_FILE" ]]; then
            RUNNING_PID="$pid"
            break 2
        fi
    done
done

if [[ -z "$RUNNING_PID" ]]; then
    echo "✗ New Caelestia failed to start."
    echo
    echo "==> Rolling back"

    "$PROJECT_ROOT/omarchy/scripts/stop-shell.sh" || true

    if [[ ! -d "$PREVIOUS_PREFIX" ]]; then
        echo "✗ Rollback copy is missing:"
        echo "  $PREVIOUS_PREFIX"
        exit 1
    fi

    rm -rf "$INSTALL_PREFIX"
    mv "$PREVIOUS_PREFIX" "$INSTALL_PREFIX"

    echo "✓ Previous installation restored."
    echo
    echo "==> Starting previous Caelestia"

    "$PROJECT_ROOT/omarchy/scripts/start-shell.sh"

    echo
    echo "✗ Update failed."
    echo "✓ Previous version restored."
    exit 1
fi

echo "✓ Caelestia is running."
echo "  PID: $RUNNING_PID"

# ------------------------------------------------------------
# COMMIT
# ------------------------------------------------------------

echo
echo "==> Update successful"

if [[ -d "$PREVIOUS_PREFIX" ]]; then
    rm -rf "$PREVIOUS_PREFIX"
    echo "✓ Previous installation removed."
fi

rm -f "$STAGING_INFO"

echo
echo "Omarchy-Caelestia is now running the new version."
echo
