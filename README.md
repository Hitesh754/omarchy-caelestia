# Omarchy + Caelestia

A Caelestia-powered desktop shell integration for Omarchy.

Bring the Caelestia desktop experience to Omarchy while keeping Omarchy's underlying system, Hyprland configuration, applications, and workflow intact.

## Architecture

Omarchy remains the system layer while Caelestia provides the visual shell layer through Quickshell.

- Omarchy — system and workflow
- Hyprland — window management
- Caelestia — desktop UI, theme, animations, bar, dashboard, launcher, OSD and notifications
- Quickshell — shell runtime

## Requirements

- Omarchy
- Hyprland
- Quickshell
- CMake
- Ninja
- Python 3
- hyprctl
- pgrep
- Qt/QML dependencies required by Caelestia

The installer checks every dependency (packages and fonts) and offers to
install anything missing with `pacman`, and `yay` for AUR packages such as
`libcava`, `qt6-m3shapes-git` and `ttf-rubik-vf`. Either `quickshell` or
`quickshell-git` satisfies the Quickshell requirement. Note that Arch's `cava`
package only ships the CLI; Caelestia builds against `libcava`.

## Installation

Clone the integration branch:

    git clone -b omarchy-integration https://github.com/Hitesh754/omarchy-caelestia.git
    cd omarchy-caelestia

Run:

    ./omarchy/install.sh

The installer checks dependencies, builds and installs Caelestia into the user's local data directory, and sets up the launcher binding, autostart, the on/off toggle and Omarchy theme sync.

Pass `--skip-deps` to skip the dependency check.

## Keybindings

| Binding | Action |
|---------|--------|
| **SUPER + SPACE** | Caelestia launcher |
| **SUPER + ALT + C** | Turn Caelestia on/off |

Both live in the managed block in `~/.config/hypr/bindings.lua`.

## Autostart and toggle

Caelestia starts at login through `omarchy-caelestia-toggle start`, installed
to `~/.local/bin`. Turning it off with the toggle (or
`omarchy-caelestia-toggle off`) persists across logins; turning it back on
restores autostart.

    omarchy-caelestia-toggle [toggle|on|off|start]

## Theme sync

An Omarchy `theme-set` hook (`~/.config/omarchy/hooks/theme-set.d/60-caelestia.sh`)
converts the active theme's `colors.toml` into Caelestia's colour scheme and
points Caelestia at the theme background. Changing the Omarchy theme recolours
Caelestia live, without a restart.

## Wallpapers

Omarchy stays in charge of the wallpaper. The installer writes
`~/.config/caelestia/shell.json` with `background.wallpaperEnabled` set to
`false` (only if that file does not exist yet), so Caelestia's background layer
stays transparent and Omarchy backgrounds and motion/video wallpaper plugins
(such as `nosignal.motion-wallpaper`) remain visible, with Caelestia's desktop
clock and visualiser drawn on top.

## Omarchy plugins in the bar

Third-party Omarchy shell plugins that add a bar widget get a place in the
Caelestia bar too. They sit behind a single puzzle-piece button: click it to
reveal one icon per plugin, and click an icon to open that plugin's popout or
panel. Omarchy's shell still runs the plugin, so it behaves exactly as it does
in the Omarchy bar, even while the Omarchy bar is hidden.

The list follows Omarchy: every enabled plugin that isn't first-party appears,
including ones added later with `omarchy plugin add ... --enable` or turned on
in a plugin manager. Disabled and built-in plugins are left out. The section
picker Omarchy shows on install only places the widget in the Omarchy bar; it
appears in Caelestia either way.

Icons come from the plugin's bar widget category. To pick your own, map plugin
ids to [Material Symbols](https://fonts.google.com/icons) names in
`~/.config/caelestia/omarchy-plugins.json`:

    {
      "icons": {
        "akshar.radio-atlas": "radio"
      }
    }

Plugin authors can also set a default with `"caelestia": { "icon": "radio" }`
in `manifest.json`.

The system tray is compact by default: its icons stay hidden behind an arrow
until you click it.

## Safety

The integration is designed not to replace Omarchy's system shell.

- Does not modify `/usr/share/omarchy/shell`.
- Refuses to use `/usr/share/omarchy/shell` as the Caelestia source.
- Creates backups before modifying the managed Hyprland bindings block.
- Validates the installation before activation.
- Supports rollback when activation or startup fails.
- Preserves user changes to the managed bindings during uninstall.
- Uninstall removes the toggle and theme hook, and the Caelestia config only if it was not edited.

## Uninstallation

    ./omarchy/uninstall.sh

## Updating

    ./omarchy/update.sh

The update flow stages a new build, activates it, verifies startup, and restores the previous installation if startup fails. It also refreshes the toggle and theme hook. Installs from before autostart existed should re-run `./omarchy/install.sh` once to get the new bindings.

## Project Structure

    caelestia-shell/
    ├── components/
    ├── modules/
    ├── services/
    ├── utils/
    ├── assets/
    ├── CMakeLists.txt
    ├── shell.qml
    └── omarchy/
        ├── install.sh
        ├── uninstall.sh
        ├── update.sh
        ├── hooks/
        │   └── theme-set-caelestia.sh
        └── scripts/
            ├── install-dependencies.sh
            ├── install-extras.sh
            └── caelestia-toggle.sh

## Status

Active development. The Omarchy integration, installer, uninstaller, rollback flow, and core shell experience have been tested on Omarchy 4.0.4 with Hyprland 0.56.2 and Quickshell 0.3.0.

## Credits

Based on **Caelestia Shell** by caelestia-dots.

Caelestia Shell is licensed under GPL-3.0.

## License

This project follows the GPL-3.0 licensing of the Caelestia Shell codebase.
See .
