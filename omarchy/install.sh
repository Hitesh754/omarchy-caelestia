#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$PROJECT_ROOT"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

INSTALL_PREFIX="$DATA_HOME/omarchy-caelestia"
SHELL_DIR="$INSTALL_PREFIX/etc/xdg/quickshell/caelestia"
SHELL_FILE="$SHELL_DIR/shell.qml"
QML_DIR="$INSTALL_PREFIX/lib/qt6/qml"
LIB_DIR="$INSTALL_PREFIX/lib/caelestia"
LINK_PATH="$CONFIG_HOME/quickshell/caelestia"

BINDINGS_FILE="$CONFIG_HOME/hypr/bindings.lua"
STATE_DIR="$STATE_HOME/omarchy-caelestia"
BACKUP_DIR="$STATE_DIR/backups"
BACKUP_STATE="$STATE_DIR/bindings-backup"
OWNED_HASH="$STATE_DIR/bindings-owned-hash"
LOG_FILE="$STATE_DIR/caelestia.log"

BLOCK_START="-- BEGIN OMARCHY-CAELESTIA: launcher"
BLOCK_END="-- END OMARCHY-CAELESTIA: launcher"

die(){ echo "✗ $*" >&2; exit 1; }
info(){ echo "==> $*"; }

[[ -d "$SOURCE_DIR" ]] || die "Caelestia source not found: $SOURCE_DIR"
[[ -f "$BINDINGS_FILE" ]] || die "Hyprland bindings not found: $BINDINGS_FILE"

for c in cmake ninja qs hyprctl python3 pgrep; do
    command -v "$c" >/dev/null || die "$c is required"
done

pgrep -x quickshell -a 2>/dev/null | grep -Fq "/usr/share/omarchy/shell" ||
    die "Omarchy shell is not detected; refusing to continue."

[[ "$SOURCE_DIR" != "/usr/share/omarchy/shell" ]] ||
    die "Refusing to use /usr/share/omarchy/shell as source."

mkdir -p "$STATE_DIR" "$BACKUP_DIR" "$CONFIG_HOME/quickshell"

if [[ -e "$LINK_PATH" && ! -L "$LINK_PATH" ]]; then
    [[ -d "$LINK_PATH" && -z "$(find "$LINK_PATH" -mindepth 1 -maxdepth 1 -print -quit)" ]] ||
        die "$LINK_PATH exists and is not an empty directory/symlink; refusing to touch it."
    rmdir "$LINK_PATH"
fi

# Existing installation must be a recognizable Caelestia install.
if [[ -e "$INSTALL_PREFIX" ]]; then
    [[ -f "$INSTALL_PREFIX/lib/caelestia/version" ]] ||
        die "$INSTALL_PREFIX exists but is not a recognized Caelestia installation; refusing to remove it."
fi

STAGING_ROOT="$(mktemp -d "$DATA_HOME/.omarchy-caelestia-install.XXXXXX")"
STAGING_PREFIX="$STAGING_ROOT/omarchy-caelestia"

INSTALLED_NEW=0
OLD_INSTALL_MOVED=0
LINK_CREATED=0
BINDINGS_CHANGED=0
BACKUP_FILE=""
NEW_PID=""

rollback(){
    local rc=$?
    [[ "$rc" -eq 0 ]] && return 0
    trap - EXIT

    echo
    echo "==> Installation failed; rolling back"

    if [[ -n "$NEW_PID" ]]; then
        kill "$NEW_PID" 2>/dev/null || true
        sleep 1
        kill -9 "$NEW_PID" 2>/dev/null || true
    fi

    if [[ "$BINDINGS_CHANGED" -eq 1 && -f "$BACKUP_FILE" ]]; then
        cp --preserve=mode,ownership,timestamps "$BACKUP_FILE" "$BINDINGS_FILE" || true
        hyprctl reload >/dev/null 2>&1 || true
    fi

    if [[ "$LINK_CREATED" -eq 1 && -L "$LINK_PATH" ]]; then
        rm -f "$LINK_PATH" || true
    fi

    if [[ "$INSTALLED_NEW" -eq 1 ]]; then
        rm -rf -- "$INSTALL_PREFIX" || true
    fi

    if [[ "$OLD_INSTALL_MOVED" -eq 1 && -d "$INSTALL_PREFIX.previous-install" ]]; then
        mv "$INSTALL_PREFIX.previous-install" "$INSTALL_PREFIX" || true
    fi

    rm -rf -- "$STAGING_ROOT" || true
    echo "✓ Rollback completed."
    exit "$rc"
}
trap rollback EXIT

info "Building Caelestia"
BUILD_DIR="$SOURCE_DIR/build"
cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR"

info "Installing into temporary staging"
mkdir -p "$STAGING_PREFIX"
cmake --install "$BUILD_DIR" --prefix "$STAGING_PREFIX"

[[ -f "$STAGING_PREFIX/etc/xdg/quickshell/caelestia/shell.qml" ]] ||
    die "Staged shell.qml is missing"
[[ -d "$STAGING_PREFIX/lib/qt6/qml/Caelestia" ]] ||
    die "Staged Caelestia QML modules are missing"
[[ -d "$STAGING_PREFIX/lib/caelestia" ]] ||
    die "Staged Caelestia libraries are missing"
[[ -f "$STAGING_PREFIX/lib/caelestia/version" ]] ||
    die "Staged version information is missing"

info "Activating validated installation"

if [[ -e "$INSTALL_PREFIX" ]]; then
    rm -rf -- "$INSTALL_PREFIX.previous-install"
    mv "$INSTALL_PREFIX" "$INSTALL_PREFIX.previous-install"
    OLD_INSTALL_MOVED=1
fi

mv "$STAGING_PREFIX" "$INSTALL_PREFIX"
INSTALLED_NEW=1

info "Configuring Quickshell"

if [[ -L "$LINK_PATH" ]]; then
    TARGET="$(readlink -f "$LINK_PATH" 2>/dev/null || true)"
    [[ "$TARGET" == "$SHELL_DIR" ]] ||
        die "Existing Quickshell link points somewhere unexpected."
    rm -f "$LINK_PATH"
fi

ln -s "$SHELL_DIR" "$LINK_PATH"
LINK_CREATED=1

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/bindings.lua.$STAMP"
cp --preserve=mode,ownership,timestamps "$BINDINGS_FILE" "$BACKUP_FILE"
printf '%s\n' "$BACKUP_FILE" > "$BACKUP_STATE"

info "Installing managed Caelestia launcher binding"

python3 - "$BINDINGS_FILE" "$BLOCK_START" "$BLOCK_END" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
start = sys.argv[2]
end = sys.argv[3]
text = path.read_text()

block = """-- BEGIN OMARCHY-CAELESTIA: launcher
hl.unbind("SUPER + SPACE")
hl.bind(
    "SUPER + SPACE",
    hl.dsp.exec_cmd("qs ipc -c caelestia call drawers toggle launcher"),
    { description = "Caelestia launcher" }
)
-- END OMARCHY-CAELESTIA: launcher"""

if start in text or end in text:
    if start not in text or end not in text:
        raise SystemExit("Incomplete Caelestia marker block found.")
    before, rest = text.split(start, 1)
    _, after = rest.split(end, 1)
    text = before.rstrip() + "\n\n" + block + after
else:
    text = text.rstrip() + "\n\n" + block + "\n"

tmp = path.with_name(path.name + ".caelestia.tmp")
tmp.write_text(text)
tmp.replace(path)
PY

BINDINGS_CHANGED=1

hyprctl reload >/dev/null
sleep 1

ERRORS="$(hyprctl configerrors 2>&1 || true)"
[[ -z "$ERRORS" || "$ERRORS" == "no errors" || "$ERRORS" == "No errors" ]] ||
    { printf '%s\n' "$ERRORS"; die "Hyprland reported configuration errors"; }

printf '%s\n' "$(sha256sum "$BINDINGS_FILE" | awk '{print $1}')" > "$OWNED_HASH"

info "Starting Caelestia"

QML2_IMPORT_PATH="$QML_DIR"

nohup env \
    QS_ICON_THEME=Adwaita \
    CAELESTIA_LIB_DIR="$LIB_DIR" \
    QML2_IMPORT_PATH="$QML2_IMPORT_PATH" \
    qs -c caelestia >"$LOG_FILE" 2>&1 &

NEW_PID=$!

RUNNING=0
for _ in {1..20}; do
    if kill -0 "$NEW_PID" 2>/dev/null &&
       tr '\0' '\n' < "/proc/$NEW_PID/environ" 2>/dev/null |
       grep -qx "CAELESTIA_LIB_DIR=$LIB_DIR"; then
        RUNNING=1
        break
    fi
    sleep .5
done

if [[ "$RUNNING" -ne 1 ]]; then
    cat "$LOG_FILE" 2>/dev/null || true
    die "Caelestia did not start successfully"
fi

if [[ "$OLD_INSTALL_MOVED" -eq 1 && -d "$INSTALL_PREFIX.previous-install" ]]; then
    rm -rf -- "$INSTALL_PREFIX.previous-install"
    OLD_INSTALL_MOVED=0
fi

rm -rf -- "$STAGING_ROOT"
trap - EXIT

echo
echo "========================================"
echo " Installation complete"
echo "========================================"
echo
printf 'Shell:      %s\nQML:        %s\nLibrary:    %s\nLauncher:   SUPER + SPACE\nPID:        %s\n' \
    "$SHELL_FILE" "$QML_DIR" "$LIB_DIR" "$NEW_PID"
echo
echo "Omarchy's /usr/share/omarchy/shell was not modified."
