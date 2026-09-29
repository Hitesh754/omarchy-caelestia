# Omarchy-Caelestia Progress

## Goal
Production-quality Omarchy + Caelestia desktop shell integration.

Omarchy owns:
- Hyprland
- keybindings
- applications
- system configuration

Caelestia owns:
- Bar
- Dashboard
- Launcher
- OSD
- Notifications
- Material theme
- animations
- widgets

NEVER modify `/usr/share/omarchy`.
NEVER kill/replace the Omarchy shell.
NEVER remove/replace `quickshell-git`.

## Current System
Omarchy: 4.0.4-1
Hyprland: 0.56.2
Quickshell: 0.3.0 (`quickshell-git`)

Omarchy shell:
`/usr/share/omarchy/shell`

## Project
Repository:
`~/Projects/omarchy-caelestia/caelestia-shell`

Installed prefix:
`~/.local/share/omarchy-caelestia`

Quickshell config:
`~/.config/quickshell/caelestia`

Environment:
`CAELESTIA_LIB_DIR=~/.local/share/omarchy-caelestia/lib/caelestia`
`QML2_IMPORT_PATH=~/.local/share/omarchy-caelestia/lib/qt6/qml`

Run:
`qs -c caelestia`

## Verified Working
- Caelestia source built successfully
- Release installation works
- Caelestia shell runs alongside Omarchy
- Dashboard works
- Launcher works
- Super+Space opens Caelestia launcher
- Omarchy shell remains untouched
- Quickshell remains installed
- Transactional staging/activation implemented
- Update script tested
- Rollback/preservation logic implemented
- Uninstall safety logic implemented
- Quickshell symlink configured
- No Caelestia systemd service

## Current Problem
Dynamic wallpaper colors do not currently update Caelestia or Waybar.

`caelestia` CLI is intentionally absent.

Current static scheme is in:
`~/.local/state/caelestia/scheme.json`

It has been using:
`catppuccin / mocha`

Do NOT blindly reinstall `caelestia-cli-git`.

## Upstream CLI Investigation
Temporary upstream checkout:
`/tmp/caelestia-cli-inspect`

Repository:
`https://github.com/caelestia-dots/cli.git`

Relevant files:

`src/caelestia/subcommands/scheme.py`
`src/caelestia/subcommands/wallpaper.py`
`src/caelestia/utils/scheme.py`
`src/caelestia/utils/wallpaper.py`
`src/caelestia/utils/colour.py`
`src/caelestia/utils/colourfulness.py`
`src/caelestia/utils/theme.py`
`src/caelestia/utils/material/__init__.py`
`src/caelestia/utils/material/generator.py`
`src/caelestia/utils/material/score.py`

## Confirmed Dynamic Color Algorithm

Wallpaper
-> thumbnail
-> ImageQuantizeCelebi
-> HCT candidates
-> Caelestia scoring
-> primary HCT color
-> Material 3 DynamicScheme
-> complete Caelestia palette
-> scheme.json

Colourfulness selects variant:
- <10: neutral
- <20: content
- >=20: tonalspot

Material variants:
- tonalspot
- vibrant
- expressive
- fidelity
- fruitsalad
- monochrome
- neutral
- rainbow
- content

Dynamic scheme regenerates colors from the wallpaper.

## Important Architecture Decision

Do NOT create an approximate/independent wallpaper color algorithm.

Reuse the upstream Caelestia Material implementation so the existing Caelestia QML receives the same palette behavior as normal Caelestia.

Desired flow:

Omarchy wallpaper
-> wallpaper state
-> Caelestia compatibility backend
-> Material palette
-> scheme.json
-> Caelestia UI
-> Waybar

One palette should be the source of truth for both Caelestia and Waybar.

## Omarchy Wallpaper
Current wallpaper state:
`~/.local/state/omarchy/current/background`

Omarchy background/live-wallpaper implementation:
`~/.config/omarchy/plugins/tenzin.live-wallpaper/live-wallpaper.sh`

DO NOT modify the Omarchy live-wallpaper script.

Use/observe Omarchy's existing state instead.

## Waybar
Next task is to inspect the current Omarchy Waybar configuration.

Then implement:
1. Caelestia CLI compatibility layer
2. Upstream Material generator integration
3. Wallpaper bridge
4. Shared palette
5. Waybar theme bridge
6. Automatic wallpaper-change synchronization
7. Installer integration
8. Failure/rollback testing

## Safety
NEVER:
- modify `/usr/share/omarchy`
- kill Omarchy shell
- remove `quickshell-git`
- replace Omarchy Hyprland configuration wholesale
- blindly reinstall old Caelestia CLI
- use sudo in project scripts

Always:
- preserve backups
- validate before activation
- use transactional installation
- support rollback
- keep UI/backend separated
- make small reviewable commits

## Tomorrow
Start by inspecting the current Omarchy Waybar configuration.

Then implement the dynamic-color backend.
