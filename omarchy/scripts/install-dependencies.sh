#!/usr/bin/env bash

set -euo pipefail

# Dependencies are checked with `pacman -T`, which resolves "provides", so a
# dependency is satisfied by any package that provides it (e.g. `quickshell`
# is satisfied by either the official quickshell package or quickshell-git).
PACKAGES=(
    "quickshell"
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
    "qt6-m3shapes"
    "swappy"
    "fish"
    "bash"
    "cmake"
    "ninja"
    "qt6-shadertools"
    "python"
)

# Packages to install when a dependency is missing and its name is not an
# installable package on its own.
declare -A CANDIDATE=(
    ["qt6-m3shapes"]="qt6-m3shapes-git"
)

echo "==> Checking Caelestia dependencies"
echo

MISSING=()

# Fonts are capability dependencies: different setups may provide the same
# family under different package names, so check fontconfig first and only
# fall back to a package when the family is not available.
if fc-list : family | awk -F',' '{ for (i = 1; i <= NF; i++) if (tolower($i) == "rubik") found = 1 } END { exit !found }'; then
    echo "✓ Rubik font"
else
    echo "⚠ Rubik font: not installed"
    MISSING+=("ttf-rubik-vf")
fi

if fc-list : family | awk 'BEGIN { IGNORECASE = 1 } /Material Symbols Rounded/ { found = 1 } END { exit !found }'; then
    echo "✓ Material Symbols Rounded"
else
    echo "⚠ Material Symbols Rounded: not installed"
    MISSING+=("ttf-material-symbols-variable")
fi

for package in "${PACKAGES[@]}"; do
    if pacman -T "$package" >/dev/null; then
        echo "✓ $package"
    else
        echo "⚠ $package: not installed"
        MISSING+=("${CANDIDATE[$package]:-$package}")
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

HAVE_YAY=0
command -v yay >/dev/null 2>&1 && HAVE_YAY=1

for package in "${MISSING[@]}"; do
    if pacman -Si "$package" &>/dev/null; then
        OFFICIAL+=("$package")
    elif (( HAVE_YAY )) && yay -Si "$package" &>/dev/null; then
        AUR+=("$package")
    else
        UNAVAILABLE+=("$package")
    fi
done

if (( ${#UNAVAILABLE[@]} > 0 )); then
    echo "✗ The following packages could not be found:"
    printf '  - %s\n' "${UNAVAILABLE[@]}"
    echo
    (( HAVE_YAY )) || echo "yay is not installed; AUR packages cannot be resolved."
    echo "Please install them manually or update the dependency list."
    exit 1
fi

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

echo
echo "==> Verifying installation"

FAILED=0

for package in "${MISSING[@]}"; do
    if pacman -T "$package" >/dev/null; then
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
