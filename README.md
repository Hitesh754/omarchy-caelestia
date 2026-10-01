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

## Installation

Clone the integration branch:

    git clone -b omarchy-integration https://github.com/Hitesh754/omarchy-caelestia.git
    cd omarchy-caelestia

Run:

    ./omarchy/install.sh

The installer builds and installs Caelestia into the user's local data directory and configures the launcher binding.

## Launcher

The default launcher binding is **SUPER + SPACE**.

## Safety

The integration is designed not to replace Omarchy's system shell.

- Does not modify .
- Refuses to use  as the Caelestia source.
- Creates backups before modifying the managed Hyprland launcher binding.
- Validates the installation before activation.
- Supports rollback when activation or startup fails.
- Preserves user changes to the managed launcher binding during uninstall.

## Uninstallation

    ./omarchy/uninstall.sh

## Updating

    ./omarchy/update.sh

The update flow stages a new build, activates it, verifies startup, and restores the previous installation if startup fails.

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
        └── scripts/

## Status

Active development. The Omarchy integration, installer, uninstaller, rollback flow, and core shell experience have been tested on Omarchy 4.0.4 with Hyprland 0.56.2 and Quickshell 0.3.0.

## Credits

Based on **Caelestia Shell** by caelestia-dots.

Caelestia Shell is licensed under GPL-3.0.

## License

This project follows the GPL-3.0 licensing of the Caelestia Shell codebase.
See .
