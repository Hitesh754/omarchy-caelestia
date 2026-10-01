#!/usr/bin/env bash

set -euo pipefail

PACKAGES=(
    "quickshell-git"
    "glibc"
    "gcc-libs"
    "ddcutil"
    "brightnessctl"
    "libcava"
    "networkmanager"
    "lm_sensors"
    "aubio"
    "libpipewire"
    "libqalculate"
    "power-profiles-daemon"
    "ttf-cascadia-code-nerd"
    "qt6-base"
    "qt6-declarative"
    "qt6-imageformats"
    "qt6-m3shapes-git"
    "swappy"
    "fish"
    "bash"
    "cmake"
    "ninja"
    "qt6-shadertools"
)

echo "==> Checking Caelestia dependencies"
echo

# Fonts are capability dependencies rather than strict package-name
# dependencies.  Different Arch/Omarchy setups may provide the same
# fonts under different package names.
if fc-list : family | awk -F',' '{ for (i = 1; i <= NF; i++) if (tolower($i) == "rubik") found = 1 } END { exit !found }'; then
    echo "✓ Rubik font"
else
    echo "⚠ Rubik font: not installed"
    echo "  Install the Rubik variable font before continuing."
    exit 1
fi

if fc-list : family | awk 'BEGIN { IGNORECASE = 1 } /Material Symbols Rounded/ { found = 1 } END { exit !found }'; then
    echo "✓ Material Symbols Rounded"
else
    echo "⚠ Material Symbols Rounded: not installed"
    echo "  Install the Material Symbols font before continuing."
    exit 1
fi

MISSING=()

for package in "${PACKAGES[@]}"; do
    if pacman -Q "$package" &>/dev/null; then
        echo "✓ $package"
    else
        echo "⚠ $package: not installed"
        MISSING+=("$package")
    fi
done

echo

if (( ${#MISSING[@]} == 0 )); then
    echo "All dependencies are installed."
    exit 0
fi

echo "Missing packages:"
printf '  - %s\n' "${MISSING[@]}"
echo

OFFICIAL=()
AUR=()
UNAVAILABLE=()

for package in "${MISSING[@]}"; do
    if pacman -Si "$package" &>/dev/null; then
        OFFICIAL+=("$package")
    elif yay -Si "$package" &>/dev/null; then
        AUR+=("$package")
    else
        UNAVAILABLE+=("$package")
    fi
done

if (( ${#OFFICIAL[@]} > 0 )); then
    echo "==> Official Arch packages"
    printf '  %s\n' "${OFFICIAL[@]}"
    echo

    read -r -p "Install these packages? [Y/n] " answer
    answer="${answer:-Y}"

    if [[ "$answer" =~ ^[Yy]$ ]]; then
        sudo pacman -S --needed "${OFFICIAL[@]}"
    else
        echo "Installation cancelled."
        exit 1
    fi
fi

if (( ${#AUR[@]} > 0 )); then
    echo
    echo "==> AUR packages"
    printf '  %s\n' "${AUR[@]}"
    echo

    read -r -p "Install these AUR packages using yay? [Y/n] " answer
    answer="${answer:-Y}"

    if [[ "$answer" =~ ^[Yy]$ ]]; then
        yay -S --needed "${AUR[@]}"
    else
        echo "AUR installation cancelled."
        exit 1
    fi
fi

if (( ${#UNAVAILABLE[@]} > 0 )); then
    echo
    echo "✗ The following packages could not be found:"
    printf '  - %s\n' "${UNAVAILABLE[@]}"
    echo
    echo "Please install them manually or update the dependency list."
    exit 1
fi

echo
echo "==> Verifying installation"

FAILED=0

for package in "${MISSING[@]}"; do
    if pacman -Q "$package" &>/dev/null; then
        echo "✓ $package"
    else
        echo "✗ $package"
        FAILED=1
    fi
done

if (( FAILED )); then
    echo
    echo "Some dependencies are still missing."
    exit 1
fi

echo
echo "All Caelestia dependencies are installed."
