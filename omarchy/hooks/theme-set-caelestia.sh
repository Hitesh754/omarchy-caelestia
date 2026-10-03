#!/usr/bin/env bash
# Sync the Caelestia shell (omarchy-caelestia) with the current Omarchy theme.
# Writes ~/.local/state/caelestia/scheme.json from the theme's colors.toml and
# points Caelestia's wallpaper at the Omarchy background. Caelestia watches both
# files, so a running shell picks up the change live.

THEME_DIR="$HOME/.local/state/omarchy/current/theme"
BACKGROUND="$HOME/.local/state/omarchy/current/background"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"

[[ -f "$THEME_DIR/colors.toml" ]] || exit 0
mkdir -p "$STATE/wallpaper"

python3 - "$THEME_DIR/colors.toml" "$STATE/scheme.json" "${1:-omarchy}" <<'PY' || exit 0
import json, os, sys, tomllib

src, out, name = sys.argv[1:4]
with open(src, "rb") as f:
    t = tomllib.load(f)

def rgb(h):
    h = h.strip().lstrip("#")[:6]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def hx(c):
    return "".join(f"{round(v):02x}" for v in c)

def mix(a, b, w):
    # w = share of b
    return tuple(x + (y - x) * w for x, y in zip(a, b))

def lum(c):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = map(ch, c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)

term = [rgb(t.get(f"color{i}", "#808080")) for i in range(16)]
bg = rgb(t.get("background", "#000000"))
fg = rgb(t.get("foreground", "#ffffff"))
accent = rgb(t.get("accent", t.get("color4", "#8888ff")))
secondary = term[6]
tertiary = term[5]
error = term[1]
success = term[2]
light = lum(bg) > 0.4

def on(c):
    return bg if contrast(c, bg) >= contrast(c, fg) else fg

def role(prefix, c):
    cont = mix(c, bg, 0.65)
    return {
        prefix: c,
        f"on{prefix.capitalize()}": on(c),
        f"{prefix}Container": cont,
        f"on{prefix.capitalize()}Container": mix(c, fg, 0.6),
    }

def fixed(prefix, c):
    cap = prefix.capitalize()
    return {
        f"{prefix}Fixed": mix(c, fg, 0.5),
        f"{prefix}FixedDim": c,
        f"on{cap}Fixed": bg,
        f"on{cap}FixedVariant": mix(c, bg, 0.6),
    }

s = lambda w: mix(bg, fg, w)
colours = {
    "primary_paletteKeyColor": accent,
    "secondary_paletteKeyColor": secondary,
    "tertiary_paletteKeyColor": tertiary,
    "neutral_paletteKeyColor": s(0.5),
    "neutral_variant_paletteKeyColor": s(0.45),
    "background": bg,
    "onBackground": fg,
    "surface": bg,
    "surfaceDim": bg if not light else s(0.08),
    "surfaceBright": s(0.20) if not light else bg,
    "surfaceContainerLowest": s(0.02),
    "surfaceContainerLow": s(0.05),
    "surfaceContainer": s(0.08),
    "surfaceContainerHigh": s(0.12),
    "surfaceContainerHighest": s(0.16),
    "onSurface": fg,
    "surfaceVariant": s(0.14),
    "onSurfaceVariant": s(0.75),
    "inverseSurface": fg,
    "inverseOnSurface": bg,
    "outline": s(0.5),
    "outlineVariant": s(0.25),
    "shadow": (0, 0, 0),
    "scrim": (0, 0, 0),
    "surfaceTint": accent,
    "inversePrimary": mix(accent, bg, 0.4),
    **role("primary", accent),
    **role("secondary", secondary),
    **role("tertiary", tertiary),
    **role("error", error),
    **role("success", success),
    **fixed("primary", accent),
    **fixed("secondary", secondary),
    **fixed("tertiary", tertiary),
}
colours = {k: hx(v) for k, v in colours.items()}
colours.update({f"term{i}": hx(c) for i, c in enumerate(term)})

scheme = {
    "name": name,
    "flavour": "omarchy",
    "mode": "light" if light else "dark",
    "variant": "omarchy",
    "colours": colours,
}
tmp = out + ".tmp"
with open(tmp, "w") as f:
    json.dump(scheme, f, indent=2)
os.replace(tmp, out)
PY

if [[ -e "$BACKGROUND" ]]; then
    readlink -f "$BACKGROUND" > "$STATE/wallpaper/path.txt.tmp" &&
        mv "$STATE/wallpaper/path.txt.tmp" "$STATE/wallpaper/path.txt"
fi
